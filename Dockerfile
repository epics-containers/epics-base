# EPICS 7 Base Dockerfile

#  build args
#   EPICS_TARGET_ARCH: the epics cross compile target platform
#     note that linux-x86_64 is shortened to linux and is the default
#   EPICS_HOST_ARCH: the epics host architecture name
#   BASE_IMAGE: can be used to bring in cross compilation tools

ARG BASE_IMAGE=ubuntu:22.04

##### shared environment stage #################################################
FROM ${BASE_IMAGE} AS environment

ARG EPICS_TARGET_ARCH=linux-x86_64
ARG EPICS_HOST_ARCH=linux-x86_64

ENV EPICS_TARGET_ARCH=${EPICS_TARGET_ARCH}
ENV EPICS_HOST_ARCH=${EPICS_HOST_ARCH}
ENV EPICS_ROOT=/epics
ENV EPICS_BASE=${EPICS_ROOT}/epics-base
ENV SUPPORT ${EPICS_ROOT}/support
ENV IOC ${EPICS_ROOT}/ioc
ENV LD_LIBRARY_PATH=${EPICS_BASE}/lib/${EPICS_HOST_ARCH}

ENV VIRTUALENV /venv
ENV PATH=${VIRTUALENV}/bin:${EPICS_BASE}/bin/${EPICS_HOST_ARCH}:${PATH}

ENV EPICS_VERSION=R7.0.8

##### developer stage ##########################################################
FROM environment AS developer

# install build tools and utilities
RUN apt-get update -y && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    build-essential \
    busybox \
    git \
    libreadline-dev \
    python3-minimal \
    python3-pip \
    python3-venv \
    re2c \
    rsync \
    ssh-client \
    vim \
    && rm -rf /var/lib/apt/lists/* \
    && busybox --install

# get and build EPICS base
COPY epics /epics
RUN bash epics/scripts/get-base.sh && \
    bash /epics/scripts/patch-epics-base.sh
RUN make -C ${EPICS_BASE} -j $(nproc); make -C ${EPICS_BASE} clean

# create a virtual environment to be used by IOCs to install ibek
RUN python3 -m venv ${VIRTUALENV}

##### runtime preparation stage ################################################
FROM developer AS runtime_prep

# get the products from the build stage and reduce to runtime assets only
RUN bash epics/scripts/move_runtime.sh /assets

##### runtime stage ############################################################
FROM environment as runtime

# add runtime system dependencies
RUN apt-get update -y && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    libpython3-stdlib \
    libreadline8 \
    python3-distutils \
    python3-minimal \
    && rm -rf /var/lib/apt/lists/*

# add products from build stage
COPY --from=runtime_prep /assets /

