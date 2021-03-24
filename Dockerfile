# EPICS 7 Base Dockerfile
FROM ubuntu:20.04
# 20.04 latest LTS: Canonical will support it with updates until April 2025
# with extended security updates until April 2030

ARG EPICS_VERSION=R7.0.5

# environment
ENV SRCDIR=/src
WORKDIR ${SRCDIR}

ENV EPICS_ROOT=/epics/${EPICS_VERSION}
ENV EPICS_BASE=${EPICS_ROOT}/base
ENV EPICS_HOST_ARCH=linux-x86_64
ENV PATH="${EPICS_BASE}/bin/${EPICS_HOST_ARCH}:${PATH}"

# install build tools
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    gcc \
    g++ \
    libextutils-makemaker-cpanfile-perl \
    make

# create user and group
ARG USERNAME=epicsuser
ARG USER_UID=1000
ARG USER_GID=${USER_UID}
# use this in child images to restore epicsuser
ENV USERNAME=${USERNAME}

RUN groupadd --gid ${USER_GID} ${USERNAME} && \
    useradd --uid ${USER_UID} --gid ${USER_GID} -s /bin/bash -m ${USERNAME} && \
    chown -R ${USERNAME}:${USERNAME} ${SRCDIR} && \
    mkdir -p /epics && chown -R ${USERNAME}:${USERNAME} /epics

USER ${USERNAME}

# get the source
ARG TARFILE=${EPICS_VERSION}.tar.gz
ARG TARROOT=epics-base-${EPICS_VERSION}


RUN curl -L -O https://github.com/epics-base/epics-base/archive/${TARFILE} && \
    tar -xf ${TARFILE} && \
    mkdir -p ${EPICS_ROOT} && \
    ln -s ${SRCDIR}/${TARROOT} ${EPICS_BASE} && \
    rm ${TARFILE}

# build
RUN make -j -C ${EPICS_BASE} && \
    make clean -j -C ${EPICS_BASE}
