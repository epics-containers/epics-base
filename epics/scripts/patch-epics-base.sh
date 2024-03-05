#!/usr/bin/env bash

THIS_DIR=$(dirname $(readlink -f $0))

# comment out the test directories from the Makefile
sed -i -E 's/(^[^#].*+= test.*$)/# \1/' \
    /epics/epics-base/Makefile \
    /epics/epics-base/modules/*/Makefile

if [[ $TARGET_ARCHITECTURE == "rtems" ]]; then
    echo "Configuring epics-base to build RTEMS beatnik"

    cp ${THIS_DIR}/rtems/CONFIG_SITE.local ${EPICS_BASE}/configure/CONFIG_SITE.local
fi
