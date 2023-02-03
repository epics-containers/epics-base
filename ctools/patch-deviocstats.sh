#!/usr/bin/env bash

THIS_DIR=$(dirname $(readlink -f $0))

if [[ $TARGET_ARCHITECTURE == "rtems" ]]; then
    echo "Patching RTEMS devIocStats"
    patch -p1 < ${THIS_DIR}/rtems-deviocstats.patch

    echo >> configure/CONFIG_SITE.Common.linux-x86_64
    echo "VALID_BUILDS=Host" >> configure/CONFIG_SITE.Common.linux-x86_64
else
    echo "No devIOCStats patch required for architecture <$TARGET_ARCHITECTURE>"
fi
