#!/bin/bash
##########################################################################
##### install script for pvxs support module #############################
##########################################################################

VERSION=1.3.2
NAME=pvxs
FOLDER=$(dirname $(readlink -f $0))

if [[ $EPICS_TARGET_ARCH == "RTEMS"* ]]; then
    echo "pvxs is not supported on RTEMS"
else
    # log output and abort on failure
    set -xe

    cd ${SUPPORT}
    git clone https://github.com/epics-base/pvxs.git -b ${VERSION} --depth 1 ${NAME}
    cd ${NAME}

    # don't build test folders
    sed -i -E 's/(^[^#].*example)/# \1/' Makefile
    sed -i -E 's/(^[^#].*test)/# \1/' Makefile

    # add in the global RELEASE file as RELEASE.local
    ln -s ${SUPPORT}/configure/RELEASE ./configure/RELEASE.local

    make -j $(nproc)
    make clean
fi
