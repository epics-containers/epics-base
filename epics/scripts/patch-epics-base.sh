#!/usr/bin/env bash

THIS_DIR=$(dirname $(readlink -f $0))

# comment out the test directories from the Makefile
sed -i -E 's/(^[^#].*+= test.*$)/# \1/' \
    /epics/epics-base/Makefile \
    /epics/epics-base/modules/*/Makefile

if [[ ${EPICS_TARGET_ARCH} == "RTEMS-beatnik" ]]; then
    echo "Configuring epics-base to build RTEMS beatnik"

    cp ${THIS_DIR}/rtems/CONFIG_SITE.local ${EPICS_BASE}/configure/CONFIG_SITE.local
elif [[ ${EPICS_TARGET_ARCH} != "linux-x86_64" ]]; then
    echo "Configuring epics-base for target ${EPICS_TARGET_ARCH}"

    touch ${EPICS_BASE}/configure/CONFIG_SITE.local
    echo CROSS_COMPILER_TARGET_ARCHS=${EPICS_TARGET_ARCH} >> \
      ${EPICS_BASE}/configure/CONFIG_SITE.local
fi