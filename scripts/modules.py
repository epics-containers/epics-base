"""
Provide a basic CLI for managing a set of EPICS support modules
"""

import os
import re
import subprocess
from pathlib import Path

import click
import ruamel.yaml as yaml

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
@click.argument("modules")
@click.option("--module", required=False)
def install(modules: Path, module: str = None):  # type: ignore
    """
    Iterate through the yaml file passed in modules and for each entry:
    - pull a support module from a repo
    - implement any patches by running the patch script
    - add it to the global dependencies
    - make it
    - fixup all configure release files in support to point at this

    arguments:
        modules:    path to a YAML file containing module definitions
        module:     when set, only make this module and skip the rest
    """
    init()
    os.chdir(SUPPORT)

    # TODO Naimh should this be done with API schema (maybe?)
    # TODO then we get validation and a nice object graph instead of nested Dict
    with open(modules, "r") as stream:
        modules = yaml.safe_load(stream)

    for name, item in modules["modules"].items():
        if module and module != name:
            continue

        tag = item.get("tag")
        git = item.get("git")
        gitargs = item.get("gitargs", "")
        makeargs = item.get("makeargs", "")
        path = item.get("path")
        tar = item.get("tar")

        sub_folder = Path(path) if path else Path(SUPPORT) / name

        if sub_folder.exists():
            print(f"{name} exists. Skippig ..")
        elif git:
            git_args = (
                f"git clone {gitargs} -q --branch {tag} " f"https://{git} {sub_folder}"
            )
            do_run(git_args)
        elif tar:
            add_tar(tar, name, tag)

        # TODO this appends multiple instances of each module if run > once
        # TODO would be helful to do a replace of previous macro entry instead
        with RELEASE.open("a") as stream:
            stream.write(f"{item['macro']}={sub_folder}\n")

        build(item.get("patch"), sub_folder, makeargs)


def add_tar(url: str, module: str, tag: str):
    """
    pull a tarred support module from a repo and expand it

    arguments:

        url:    url to a tar file
        module: module name of the epics support module
        tag:    the git tag of the specific version to pull
    """
    sub_folder = Path(SUPPORT) / module
    url = url.format(TAG=tag)

    wget_args = f"wget {url}"
    do_run(wget_args)

    tar_file = url.split("/")[-1]
    tar_args = f"tar zxf {tar_file}"
    do_run(tar_args)

    new_folder = Path(tar_file[0 : tar_file.find(".tar")])
    # throw away tar file to keep image size tight
    Path(tar_file).unlink()
    new_folder.rename(sub_folder)


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


def do_run(command: str, errors=True):
    print(command)
    # use bash for enviroment variable expansion
    p = subprocess.run(command, shell=True)
    if p.returncode != 0 and errors:
        raise RuntimeError("subprocess failed.")


def build(patch: Path, sub_folder: Path, makeargs: str):
    if patch:
        do_run(f"bash {patch}")

    do_dependencies()
    do_run(f"make {makeargs} -C {sub_folder}")
    do_run(f"make {makeargs} clean -C {sub_folder}", errors=False)


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
    s = "$(SUPPORT)/"
    paths = [path[len(s)] for path in versions.values() if path.startswith(s)]
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
