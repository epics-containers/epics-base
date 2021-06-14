# EPICS 7 Base Dockerfile
FROM ubuntu:20.04
# 20.04 latest LTS: Canonical will support it with updates until April 2025
# with extended security updates until April 2030

ARG EPICS_VERSION=R7.0.5

# tell github packages that the image belongs to this repo
LABEL org.opencontainers.image.source https://github.com/epics-containers/epics-base

# install build tools
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    g++ \
    git \
    libextutils-makemaker-cpanfile-perl \
    make \
    && rm -rf /var/lib/apt/lists/*

# environment
ENV EPICS_ROOT=/epics
ENV EPICS_BASE=${EPICS_ROOT}/epics-base
ENV EPICS_HOST_ARCH=linux-x86_64
ENV PATH="${EPICS_BASE}/bin/${EPICS_HOST_ARCH}:${PATH}"

# create a user and group to run the iocs under
ENV USERNAME=k8s-epics-iocs
ENV USER_UID=37630
ENV USER_GID=37795

RUN groupadd --gid ${USER_GID} ${USERNAME} && \
    useradd --uid ${USER_UID} --gid ${USER_GID} -s /bin/bash -m ${USERNAME} && \
    mkdir -p ${EPICS_ROOT} && chown -R ${USERNAME}:${USERNAME} ${EPICS_ROOT}

USER ${USERNAME}
WORKDIR ${EPICS_ROOT}

# get the epics-base source including the PVA submodules
RUN git clone --recursive --depth 1 -b ${EPICS_VERSION} https://github.com/epics-base/epics-base.git

# build
RUN make -j -C ${EPICS_BASE} && \
    make clean -j -C ${EPICS_BASE}
