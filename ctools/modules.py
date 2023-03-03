"""
Provide a basic CLI for managing a set of EPICS support modules
"""

import os
import re
import subprocess
from pathlib import Path

import click

# note requirement for enviroment variable EPICS_BASE
EPICS_BASE = Path(str(os.getenv("EPICS_BASE")))
EPICS_ROOT = EPICS_BASE.parent
# all support modules will reside under this directory
SUPPORT = Path(f"{EPICS_ROOT}/support/")
# the global RELEASE file which lists all support modules
RELEASE = Path(f"{SUPPORT}/configure/RELEASE")
# a bash script to export the macros defined in RELEASE as environment vars
RELEASE_SH = Path(f"{SUPPORT}/configure/RELEASE.shell")
# global MODULES file used to determine order of build
MODULES = Path(f"{SUPPORT}/configure/MODULES")

# find macro name and macro value in a RELEASE file
PARSE_MACROS = re.compile(r"^([A-Z_a-z0-9]*)\s*=\s*(.*)$", flags=re.M)
# turn RELEASE macros into bash macros
SHELLIFY_FIND = re.compile(r"\$\(([^\)]*)\)")
SHELLIFY_REPLACE = r"${\1}"


@click.group(invoke_without_command=True)
@click.version_option()
@click.pass_context
def cli(ctx):
    """command line interface functions for epics support module management"""

    # if no command is supplied, print the help message
    if ctx.invoked_subcommand is None:
        click.echo(cli.get_help(ctx))


@cli.command()
@click.argument("macro", type=str)
@click.argument("tag", type=str)
@click.argument("source", type=str)
@click.option("--path", default="", type=click.Path())
@click.option("--patch", default="", type=click.Path())
@click.option("--git_args", default="", type=str)
def install(
    macro: str,
    tag: str,
    source: str,
    path: Path,
    patch: Path,
    git_args: str,
):
    """
    Iterate through the yaml file passed in modules and for each entry:
    - pull a support module from a repo
    - implement any patches by running the patch script
    - add it to the global dependencies
    - make it
    - fixup all configure release files in support to point at this

    arguments:
        macro:      macro name to use in RELEASE file
        tag:        tag to checkout
        source:     git repo or tar url to pull from
        path:       path to root location for module
        patch:      path to patch script
        git_args:   additional arguments to pass to git
    """
    init()

    if path == "":
        name = macro.lower()
        path = SUPPORT / name
    else:
        path = Path(path)
        name = path.stem

    if path.exists():
        print(f"{name} exists. Skipping ..")
    elif source.endswith(".git"):
        git_args = f"git clone {git_args} -q --branch {tag} " f"https://{source} {path}"
        do_run(git_args)
    else:
        add_tar(source, path, tag)

    if patch != "":
        patch = Path(patch).resolve()
        # cwd allows patch scripts to assume they are in the root of their repo
        do_run(f"bash {patch}", cwd=path)

    global_patch = Path("_global/global.sh").resolve()
    if global_patch.exists():
        print(f"applying global patchfile at {global_patch}")
        do_run(f"bash {global_patch}", cwd=path)
    else:
        print(f"no global patchfile at {global_patch}")

    # add or replace our macro pointing to our module path in the RELEASE file
    with RELEASE.open("r") as stream:
        lines = stream.readlines()
    outlines = []
    replaced = False
    for line in lines:
        if line.startswith(f"{macro}="):
            outlines.append(f"{macro}={path}\n")
            replaced = True
        else:
            outlines.append(line)
    if not replaced:
        outlines.append(f"{macro}={path}\n")

    with RELEASE.open("w") as stream:
        stream.writelines(outlines)

    do_dependencies()


def add_tar(url: str, path: Path, tag: str):
    """
    pull a tarred support module from a repo and expand it

    arguments:

        url:    url to a tar file
        path:   path to root location for module
        tag:    the git tag of the specific version to pull
    """
    url = url.format(TAG=tag)
    folder = path.parent

    print(f"downloading {url} to {folder}")
    wget_args = f"wget {url} -P {folder}"
    do_run(wget_args)

    tar_file = str(folder / url.split("/")[-1])
    tar_args = f"tar zxf {tar_file} -C {folder}"
    do_run(tar_args)

    new_folder = folder / tar_file[0 : tar_file.find(".tar")]
    # throw away tar file to keep image size tight
    Path(tar_file).unlink()
    print(f"moving {new_folder} to {path}")
    new_folder.rename(path)


def init():
    """
    bootstrap dependency management by creating EPICS_ROOT/support/configure/RELEASE
    to include macros defining the location of EPICS_BASE and SUPPORT
    """
    if not RELEASE.exists():
        if not RELEASE.parent.exists():
            RELEASE.parent.mkdir(parents=True)

        header = f"""
SUPPORT={SUPPORT}
-include $(TOP)/configure/SUPPORT.$(EPICS_HOST_ARCH)
-include $(TOP)/configure/EPICS_BASE
-include $(TOP)/configure/EPICS_BASE.$(EPICS_HOST_ARCH)

"""
        RELEASE.write_text(header)

        print(f"created {RELEASE}")

        # set up git to not get annoyed with detached clones
        do_run("git config --global advice.detachedHead false")


def do_run(command: str, errors=True, cwd=None):
    print(command)
    # use bash for enviroment variable expansion
    p = subprocess.run(command, shell=True, cwd=cwd)
    if p.returncode != 0 and errors:
        raise RuntimeError("subprocess failed.")


def do_dependencies():
    # parse the global release file
    versions = {}
    text = RELEASE.read_text()
    for match in PARSE_MACROS.findall(text):
        versions[match[0]] = match[1]

    # find all the configure folders
    configure_folders = SUPPORT.glob("*/configure")
    for configure in configure_folders:
        release_files = configure.glob("RELEASE*")
        # iterate over all release files
        for rel in release_files:
            orig_text = text = rel.read_text()
            # find any occurrences of global macros and replace with global value
            for macro, val in versions.items():
                replace = re.compile(f"^({macro}*\\s*=[ \t]*)(.*)$", flags=re.M)
                text = replace.sub(r"\1" + val, text)
            if orig_text != text:
                print(f"updating dependencies in {rel}")
                rel.write_text(text)

    # generate the MODULES file for inclusion into the root Makefile
    # it simply defines a variable to hold each of the support module
    # directories in the order they are presented in RELEASE, except that
    # the IOC is always listed last, if present.
    s = str(SUPPORT)
    print(s, versions.values())
    paths = [path[len(s) + 1 :] for path in versions.values() if path.startswith(s)]
    if "IOC" in versions:
        paths.append(versions["IOC"])
    modlist = f'MODULES := {" ".join(paths)}\n'
    MODULES.write_text(modlist)

    # generate RELEASE.sh file for inclusion into the ioc launch shell script.
    # This adds all module paths to the environment and also adds their db
    # folders to the database search path env variable EPICS_DB_INCLUDE_PATH
    release_sh = []
    for module, path in versions.items():
        release_sh.append(f'export {module}="{path}"')

    db_paths = [f"{path}/db" for path in versions.values() if path.startswith(s)]
    db_path_list = ":".join(db_paths)
    release_sh.append(f'export EPICS_DB_INCLUDE_PATH="{db_path_list}"')

    shell_text = "\n".join(release_sh) + "\n"
    shell_text = SHELLIFY_FIND.sub(SHELLIFY_REPLACE, shell_text)
    RELEASE_SH.write_text(shell_text)


@cli.command()
def dependencies():
    """
    update the dependencies of all support modules so that they are all
    consistent within EPICS_ROOT/support
    """
    do_dependencies()


if __name__ == "__main__":
    cli()
    # for quick debugging of e.g. dependencies function change to:
    # cli(["dependencies"])
