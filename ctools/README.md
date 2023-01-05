# ctools folder

## Purpose

All scripts and patch files needed to run the container build are
held in this folder.

Having a single folder for all of these files means that it can
be mounted for debugging the build interactively as described below.

## Debugging the container build locally

Start with first attempted build as follows:

    cd <root of your clone of this repo>
    podman build .

If this fails find the IMAGE_ID of the most recent build using:

    podman images

We can now run up this image in a container and it will hold all of the
completed steps that were successful in the above build.

We want to launch this container with the `ctools` folder mounted into it.
The files in `ctools` define the behaviour of the container build and can
be modified in your IDE outside of the container.

So launch as follows (assuming the recent image id was fd32e630e87a)::

    podman run fd32e630e87a -it --security-opt=label=disable -v $(pwd)/ctools:/ctools --name debug

Now you can manually run the steps in the Dockerfile to reproduce the issue
that broke the container build. You can modify files in `ctools` folder to
fix the issue and retry. From outside of the container you can commit the
changes you have made in `ctools`.

In particular when it comes to building modules you can use the python
modules.py (to be replaced with an ibek command). You can instruct it to
only build one of the modules in your *.modules.yaml file. e.g.:

    python /ctools/modules.py build iocStats

Will only build the single module iocStats. This allows you to debug one
module at a time. Re-running the command will do an incremental build.

