#!/usr/bin/env bash

THIS_DIR=$(dirname $(readlink -f $0))

# comment out the test directories from the Makefile
sed -i -E 's/(^[^#].*+= test.*$)/# \1/' \
    /epics/epics-base/Makefile \
    /epics/epics-base/modules/*/Makefile

if [[ $TARGET_ARCHITECTURE == "RTEMS-beatnik" ]]; then
    echo "Configuring epics-base to build RTEMS beatnik"

    cp ${THIS_DIR}/rtems/CONFIG_SITE.local ${EPICS_BASE}/configure/CONFIG_SITE.local
elif [[ $TARGET_ARCHITECTURE != "linux-x86_64" ]]; then
    echo "Configuring epics-base for target ${TARGET_ARCHITECTURE}"

    touch ${EPICS_BASE}/configure/CONFIG_SITE.local
    echo CROSS_COMPILER_TARGET_ARCHS=${TARGET_ARCHITECTURE} >> \
      ${EPICS_BASE}/configure/CONFIG_SITE.local
fi