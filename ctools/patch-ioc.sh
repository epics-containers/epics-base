#!/bin/bash

# make the IOC build for RTEMS if that is the target

if [[ $TARGET_ARCHITECTURE == "rtems" ]]; then
    cd ${IOC}
    echo CROSS_COMPILER_TARGET_ARCHS=RTEMS-beatnik >> configure/CONFIG_SITE
    echo "VALID_BUILDS=Host" >> configure/CONFIG_SITE.Common.linux-x86_64
fi
