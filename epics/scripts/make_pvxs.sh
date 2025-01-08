#!/bin/bash
##########################################################################
##### install script for pvxs support module #############################
##########################################################################

VERSION=1.3.2
NAME=pvxs

# Can't build for RTEMS because we need libevent-dev - how do we get that?
# Can't build for aarch64 - I think the Makefile assumes that the perl
# scripts exist in linux-x86_64 folders
if [[ $EPICS_TARGET_ARCH == "linux-x86_64" ]]; then
    # log output and abort on failure
    set -xe

    cd ${SUPPORT}
    git clone https://github.com/epics-base/pvxs.git -b ${VERSION} --depth 1 ${NAME}
    cd ${NAME}

    # don't build test folders
    sed -i -E 's/(^[^#].*example)/# \1/' Makefile
    sed -i -E 's/(^[^#].*test)/# \1/' Makefile

    # add in the global RELEASE file as
    ln -s ${SUPPORT}/configure/RELEASE ./configure/RELEASE.local

    make -j $(nproc)
    make clean
fi
