#!/usr/bin/env bash

THIS_DIR=$(dirname $(readlink -f $0))

# don't compile tests - saving container space
sed -i /epics/epics-base/modules/*/Makefile -e '/\+\= test/d'
rm -r /epics/epics-base/modules/*/test*

if [[ $TARGET_ARCHITECTURE == "rtems" ]]; then
    echo "Configuring epics-base to build RTEMS beatnik only"

    echo "VALID_BUILDS=Host" >> ${EPICS_BASE}/configure/CONFIG_SITE.Common.linux-x86_64

    cp ${THIS_DIR}/rtems/CONFIG_SITE.local ${EPICS_BASE}/configure/CONFIG_SITE.local
fi
