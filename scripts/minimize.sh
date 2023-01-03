#!/bin/bash

# a script to minimuize support modules for a runtime container
# moves the output folders only to dest and strips the symbols from binaries
# usage:
# ./minimize.sh src dest
#
# src:  directory to look for subfolders to be minimized
#       (e.g. /reps/epics/support)
# dest: destination for stripped binaries and folders
#
# this is destructive of the source directory (for speed) so is intended
# for use in a discarded container build stage

set -xe
shopt -s extglob

from=${1:-$(pwd)}
dest=${2:-/MIN_ROOT}

# loop over all folders in the source directory
cd ${from}
for folder in $(ls -d */) ; do
    # support modules have a configure folder
    if [[ -d ${folder}/configure ]] ; then
        mkdir -p ${dest}/${folder}
        # move the output folders to dest
        move=$(ls -d ${folder}/*(bin|configure|db|dbd|include|lib|template)/)
        mv ${move} ${dest}/${folder}

        # strip symbols from all binaries
        for binfolder in ${dest}/${folder}/*(bin|lib) ; do
            strip ${binfolder}/linux-x86_64/* || :
            if [[ -f /rtems/toolchain/powerpc-rtems5/bin/strip ]] ; then
                /rtems/toolchain/powerpc-rtems5/bin/strip ${binfolder}/RTEMS-beatnik/* || :
            fi
        done
    else
        # non support modules moved verbatim
        mv ${from}/${folder} ${dest}/${folder}
    fi
done