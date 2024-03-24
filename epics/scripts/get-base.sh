#!/bin/bash

# get the version of epics-base indicated by the environment unless we
# are building for RTEMS6 which is temporarily in a forked version

if [[ ${EPICS_TARGET_ARCH} == "RTEMS-beatnik" ]] ; then
    git clone https://github.com/kiwichris/epics-base.git \
      --branch rtems-legacy-net-support -q \
      --recursive ${EPICS_BASE}
else
    git clone https://github.com/epics-base/epics-base \
      --branch ${EPICS_VERSION} -q \
      --recursive ${EPICS_BASE}
fi