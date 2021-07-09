# EPICS 7 Base Dockerfile
FROM ubuntu:20.04 AS builder
# 20.04 latest LTS: Canonical will support it with updates until April 2025
# with extended security updates until April 2030

ARG EPICS_VERSION=R7.0.5

# install build tools and utilities
RUN apt-get update -y && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    build-essential \
    busybox-static \
    git \
    && rm -rf /var/lib/apt/lists/*

# get the epics-base source including PVA submodules - minimizing image size
RUN git config --global advice.detachedHead false && \
    git clone --recursive --depth 1 -b ${EPICS_VERSION} https://github.com/epics-base/epics-base.git && \
    rm -fr .git && \
    sed -i 's/\(^OPT.*\)-g/\1-g0/' epics-base/configure/os/CONFIG_SITE.linux-x86_64.linux-x86_64

# build
RUN make -j -C epics-base && \
    make clean -j -C epics-base

FROM ubuntu:20.04 AS epics-base

# environment
ENV EPICS_ROOT=/epics
ENV EPICS_BASE=${EPICS_ROOT}/epics-base
ENV EPICS_HOST_ARCH=linux-x86_64
ENV PATH="${EPICS_BASE}/bin/${EPICS_HOST_ARCH}:${PATH}"
ENV LD_LIBRARY_PATH=${EPICS_BASE}/lib/linux-x86_64

# create a user and group to run the iocs under
ENV USERNAME=k8s-epics-iocs
ENV USER_UID=37630
ENV USER_GID=37795

RUN groupadd --gid ${USER_GID} ${USERNAME} && \
    useradd --uid ${USER_UID} --gid ${USER_GID} -s /bin/bash -m ${USERNAME} && \
    mkdir -p ${EPICS_ROOT} && chown -R ${USERNAME}:${USERNAME} ${EPICS_ROOT}

USER ${USERNAME}

# get the products from the builder phase
COPY --from=builder epics-base ${EPICS_BASE}
