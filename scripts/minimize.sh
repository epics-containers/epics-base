#!/bin/bash

set -xe

newroot=/MIN_ROOT

mkdir -p ${newroot}

# copy over the output folders, leaving the source behind
for product in bin cfg configure db dbd include lib startup templates ; do
    mv ${EPICS_BASE}/${product} ${newroot}
done

# strip symbols from the binaries
for arch in $(ls ${newroot}/bin) ; do
    # ignore errors as not all files in these folders are binaries
    if [[ ${arch} == "RTEMS-beatnik" ]]; then
        strip=/rtems/toolchain/powerpc-rtems5/bin/strip
    else
        strip=strip
    fi
    ${strip} ${newroot}/bin/${arch}/* || :
    ${strip} ${newroot}/lib/${arch}/* || :
done
