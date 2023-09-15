#!/usr/bin/env bash

THIS_DIR=$(dirname $(readlink -f $0))

if [[ $TARGET_ARCHITECTURE == "rtems" ]]; then
    echo "Patching RTEMS epics-base"

    RTEMS_KERNEL=${RTEMS_TOP}/rtems
    RTEMS_TOOLCHAIN=${RTEMS_TOP}/toolchain

    cd ${EPICS_ROOT}/epics-base
    patch -p1 < ${THIS_DIR}/rtems-epics-base.patch
    echo "RTEMS_KERNEL = ${RTEMS_KERNEL}" >> configure/CONFIG_SITE.local
    echo "RTEMS_TOOLCHAIN = ${RTEMS_TOOLCHAIN}" >> configure/CONFIG_SITE.local
    cat configure/CONFIG_SITE.local
else
    echo "No epics-base patch required for architecture <$TARGET_ARCHITECTURE>"
fi
