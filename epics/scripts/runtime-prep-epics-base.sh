#!/usr/bin/env bash

THIS_DIR=$(dirname $(readlink -f $0))

if [[ $TARGET_ARCHITECTURE == "rtems" ]]; then
    echo "removing non rtems architecture binaries"
    rm -rf ${EPICS_BASE}/bin/${EPICS_HOST_ARCH}
    rm -rf ${EPICS_BASE}/lib/${EPICS_HOST_ARCH}
fi
