#!/usr/bin/env bash
RTEMS_KERNEL=${RTEMS_TOP}/rtems
RTEMS_TOOLCHAIN=${RTEMS_TOP}/toolchain

cd ${EPICS_ROOT}/epics-base
patch -p1 < /ctools/rtems-epics-base.patch
echo "RTEMS_KERNEL = ${RTEMS_KERNEL}" >> configure/CONFIG_SITE.local
echo "RTEMS_TOOLCHAIN = ${RTEMS_TOOLCHAIN}" >> configure/CONFIG_SITE.local
cat configure/CONFIG_SITE.local