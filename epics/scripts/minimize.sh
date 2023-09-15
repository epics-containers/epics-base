#!/bin/bash

# a script to minimuize modules for a runtime container
# moves the output folders only to CWD and strips the symbols from binaries
# usage:
# minimize.sh src1 src2 src3
#
# the src folders are moved to the CWD and trimmed (if the
# folder is an EPICS module)
# The full path of the original folder is preserved under the CWD.
#
# this is destructive of the source directory (for speed) so is intended
# for use in a discarded container build stage

set -xe
shopt -s extglob

dest=$(pwd)

if [[ $TARGET_ARCHITECTURE == "rtems" ]]; then
    # As RTEMS is statically linked the base and support modules are not needed
    folder=${IOC}
fi

# loop over all module folders we were passed
for folder in ${*} ; do

    # epics modules have a configure folder
    if [[ -d ${folder}/configure ]] ; then
        mkdir -p ./${folder}
        # move the output folders to CWD
        move=$(ls -d ${folder}/*(bin|configure|db|dbd|include|lib|template|ibek)/)
        mv ${move} ./${folder}

        # strip symbols from all binaries
        for binfolder in ${dest}/${folder}/*(bin|lib) ; do
            strip ${binfolder}/linux-x86_64/* || :
            if [[ $TARGET_ARCHITECTURE == "rtems" ]] ; then
                /rtems/toolchain/powerpc-rtems5/bin/strip ${binfolder}/RTEMS-beatnik/* || :
            fi
        done
    else
        # non-module: move the whole folder verbatim to CWD
        mkdir -p ./$(dirname ${folder}) # make sure parent exists
        mv ${folder} ./${folder}
    fi
done
