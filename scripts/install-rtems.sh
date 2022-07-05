#!/usr/bin/env bash

set -x

apt-get update -y && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    bison \
    diffutils \
    flex \
    pax \
    texinfo \
    unzip \
    && rm -rf /var/lib/apt/lists/*

RTEMS_MAJOR_VERSION=5
RTEMS_MINOR_VERSION=1
RTEMS_TOP="${1:-/rtems}"
RTEMS_BSP="beatnik"
RTEMS_SRC=rtems-${RTEMS_MAJOR_VERSION}.${RTEMS_MINOR_VERSION}
cd ${RTEMS_TOP}

# Deal with dependencies
mkdir ${RTEMS_SRC}
cd ${RTEMS_SRC}
git clone https://github.com/RTEMS/rtems-source-builder.git rsb
cd rsb
git checkout ${RTEMS_MAJOR_VERSION}.${RTEMS_MINOR_VERSION}
cd rtems
../source-builder/sb-set-builder --source-only-download ${RTEMS_MAJOR_VERSION}/rtems-powerpc
cd ../..
mkdir kernel
cd kernel
git clone git://git.rtems.org/rtems.git rtems
cd rtems
git checkout ${RTEMS_MAJOR_VERSION}.${RTEMS_MINOR_VERSION}

# Deal with toolchain
cd ${RTEMS_TOP}/${RTEMS_SRC}/rsb/rtems
../source-builder/sb-set-builder --prefix=${RTEMS_TOP}/toolchain \
    ${RTEMS_MAJOR_VERSION}/rtems-powerpc
export PATH=${RTEMS_TOP}/toolchain/bin:$PATH

# Deal with RTEMS
cd ${RTEMS_TOP}/${RTEMS_SRC}/kernel/rtems
sed -i \
    's/#define _VME_A32_WIN0_ON_VME .*/#define _VME_A32_WIN0_ON_VME 0x00800000/' \
    bsps/powerpc/beatnik/include/bsp/VMEConfig.h
./bootstrap -c && ./rtems-bootstrap
mkdir -p ${RTEMS_TOP}/build/${RTEMS_BSP}
cd ${RTEMS_TOP}/build/${RTEMS_BSP}
${RTEMS_TOP}/${RTEMS_SRC}/kernel/rtems/configure --prefix=${RTEMS_TOP}/rtems \
    --enable-maintainer-mode --target=powerpc-rtems${RTEMS_MAJOR_VERSION} \
    --enable-rtemsbsp=${RTEMS_BSP} --enable-posix --enable-c++ \
    --enable-networking
make -j $(nproc) all
make install
rm -rf ${RTEMS_TOP}/build ${RTEMS_TOP}/${RTEMS_SRC}
