#!/usr/bin/env bash

THIS_DIR=$(dirname $(readlink -f $0))

# comment out the test directories from the Makefile
sed -i -E 's/(^[^#].*+= test.*$)/# \1/' \
    /epics/epics-base/Makefile
    # No longer adding submodules to the build
    # /epics/epics-base/modules/*/Makefile

if [[ ${EPICS_TARGET_ARCH} == "RTEMS-beatnik" ]]; then
    echo "Configuring epics-base to build RTEMS beatnik"

    cp ${THIS_DIR}/rtems/CONFIG_SITE.local ${EPICS_BASE}/configure/CONFIG_SITE.local
elif [[ ${EPICS_TARGET_ARCH} != "${EPICS_HOST_ARCH}" ]]; then
    echo "Configuring epics-base for target ${EPICS_TARGET_ARCH}"

    touch ${EPICS_BASE}/configure/CONFIG_SITE.local
    echo CROSS_COMPILER_TARGET_ARCHS=${EPICS_TARGET_ARCH} >> \
      ${EPICS_BASE}/configure/CONFIG_SITE.local
fi

# GCC 15 (Ubuntu resolute) defaults to C23, in which 'long (*)()' means
# 'long (*)(void)'. Many support modules declare dsets that way and fail to
# compile, so default to gnu17 (the GCC 13/14 default) for linux targets.
# POSIX_CFLAGS comes first in CFLAGS, so a module's own -std= still wins.
cat >> ${EPICS_BASE}/configure/os/CONFIG_SITE.Common.linuxCommon <<'END'

# epics-containers: keep the pre GCC 15 default C dialect (see patch-epics-base.sh)
POSIX_CFLAGS += -std=gnu17
END
