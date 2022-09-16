#!/bin/bash

# a script to minimuize support modules for a runtime container
# moves the output folders only to dest and strips the symbols from binaries
# usage:
# ./minimize.sh src1 src2 src3
#
# the src folders are moved to the CWD and trimmed (if the 
# folder is an EPICS module)
# The full path of the original folder is preserved under the CWD.
#
# this is destructive of the source directory (for speed) so is intended
# for use in a discarded container build stage

set -xe
shopt -s extglob

# loop over all module folders we were passed
for folder in ${*} ; do
    mkdir -p ./${folder}
    # epics modules have a configure folder
    if [[ -d ${folder}/configure ]] ; then
        # move the output folders to CWD
        move=$(ls -d ${folder}/*(bin|configure|db|dbd|include|lib|template)/)
        mv ${move} ./${folder}

        # strip symbols from all binaries 
        for binfolder in ./${folder}/*(bin|lib) ; do
            strip ${binfolder}/*/* || :
        done
    else
        # non-modules are moved verbatim to CWD
        mv ${folder} ./${folder}
    fi
done
