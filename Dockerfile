# EPICS 7 Base Dockerfile

##### shared environment stage #################################################

# mandatory build args
#   TARGET_ARCHITECTURE: the epics cross compile target platform: rtems or linux
#   TARGETARCH: the buildx platform: amd64 or arm64

ARG TARGET_ARCHITECTURE

FROM ubuntu:22.04 AS base

##### architecture stages ######################################################

# use buildx target platform to determine the base image architecture
FROM base AS environment-amd64
ENV EPICS_HOST_ARCH=linux-x86_64

FROM base AS environment-arm64
ENV EPICS_HOST_ARCH=linux-arm

ENV TARGETARCH=${TARGETARCH}

##### shared environment stage #################################################

FROM environment-${TARGETARCH} AS environment

ARG TARGET_ARCHITECTURE

ENV TARGET_ARCHITECTURE=${TARGET_ARCHITECTURE}
ENV EPICS_ROOT=/epics
ENV EPICS_BASE=${EPICS_ROOT}/epics-base
ENV LD_LIBRARY_PATH=${EPICS_BASE}/lib/${EPICS_HOST_ARCH}
ENV VIRTUALENV /venv
ENV PATH=${VIRTUALENV}/bin:${EPICS_BASE}/bin/${EPICS_HOST_ARCH}:${PATH}
ENV SUPPORT ${EPICS_ROOT}/support
ENV IOC ${EPICS_ROOT}/ioc

ENV EPICS_BASE_SRC=https://github.com/epics-base/epics-base
ENV EPICS_VERSION=R7.0.8


##### developer / build stage ##################################################

FROM environment AS devtools

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

##### unique developer setup for linux soft iocs ###############################

FROM devtools AS developer-linux

# nothing additional to do for linux

##### unique developer setup for rtems iocs ####################################

FROM devtools AS developer-rtems

ENV RTEMS_VERSION=6.1-rc2
ENV RTEMS_TOP_FOLDER=/rtems${RTEMS_VERSION}-beatnik-legacy
ENV RTEMS_BASE=${RTEMS_TOP_FOLDER}/rtems/${RTEMS_VERSION}/

# clone from a fork while this while EPICS rtems 6 is still under development
ENV EPICS_BASE_SRC=https://github.com/kiwichris/epics-base.git
ENV EPICS_VERSION=rtems-legacy-net-support

# pull in RTEMS BSP
COPY --from=ghcr.io/epics-containers/rtems6-powerpc-linux-developer:6.2rc1 ${RTEMS_BASE} ${RTEMS_BASE}

##### shared build stage #######################################################

FROM developer-${TARGET_ARCHITECTURE} AS developer

# copy initial epics folder structure
COPY epics /epics

# get and build EPICS base
RUN git clone ${EPICS_BASE_SRC} -q --branch ${EPICS_VERSION} --recursive ${EPICS_BASE}
RUN bash /epics/scripts/patch-epics-base.sh
RUN make -C ${EPICS_BASE} -j $(nproc)

# also build the sequencer as it is used by many support modules
RUN bash /epics/scripts/get-sncseq.sh
RUN make -C ${SUPPORT}/sncseq -j $(nproc)

# setup a global python venv and install ibek
COPY requirements.txt /requirements.txt
RUN python3 -m venv ${VIRTUALENV} && pip install -r /requirements.txt

##### runtime preparation stage ################################################

FROM developer AS runtime_prep

# get the products from the build stage and reduce to runtime assets only
RUN ibek ioc extract-runtime-assets /assets --no-defaults --extras /venv

##### runtime stage ############################################################

FROM environment as runtime

# add runtime system dependencies
RUN apt-get update -y && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    libpython3-stdlib \
    libreadline8 \
    python3-minimal \
    && rm -rf /var/lib/apt/lists/*

# add products from build stage
COPY --from=runtime_prep /assets /

