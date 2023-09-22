# EPICS 7 Base Dockerfile

##### shared environment stage #################################################

# mandatory build args
#   TARGET_ARCHITECTURE: the epics cross compile target platform: rtems or linux
#   TARGETARCH: the buildx platform: amd64 or arm64

ARG TARGET_ARCHITECTURE

FROM ubuntu:22.04 AS base

FROM base AS environment-amd64
ENV EPICS_HOST_ARCH=linux-x86_64

FROM base AS environment-arm64
ENV EPICS_HOST_ARCH=linux-arm

ENV TARGETARCH=${TARGETARCH}

FROM environment-${TARGETARCH} AS environment

ARG TARGET_ARCHITECTURE

ENV TARGET_ARCHITECTURE=${TARGET_ARCHITECTURE}
ENV EPICS_ROOT=/epics
ENV EPICS_BASE=${EPICS_ROOT}/epics-base
ENV LD_LIBRARY_PATH=${EPICS_BASE}/lib/${EPICS_HOST_ARCH}
ENV VIRTUALENV /venv
ENV PATH=${VIRTUALENV}/bin:${EPICS_BASE}/bin/${EPICS_HOST_ARCH}:${PATH}
ENV SUPPORT ${EPICS_ROOT}/support
ENV GLOBAL_RELEASE ${SUPPORT}/configure/RELEASE
ENV IOC ${EPICS_ROOT}/ioc
ENV RTEMS_TOP=/rtems
ENV EPICS_VERSION=R7.0.7


##### developer / build stage ##################################################

FROM environment AS devtools

# install build tools and utilities
RUN apt-get update -y && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    build-essential \
    busybox \
    git \
    python3-minimal \
    python3-pip \
    python3-venv \
    re2c \
    rsync \
    ssh-client \
    && rm -rf /var/lib/apt/lists/* \
    && busybox --install

##### unique developer setup for linux soft iocs ###############################

FROM devtools AS developer-linux

# nothing additional to do for linux

##### unique developer setup for rtems iocs ####################################

FROM devtools AS developer-rtems

# pull in RTEMS toolchain

# TODO DISABLED FOR FASTER DEVELOPMENT OF linux changes (plus I run out of var space)
# RTEMS Build approach is up for review
# COPY --from=ghcr.io/epics-containers/rtems-powerpc:1.0.0 ${RTEMS_TOP} ${RTEMS_TOP}

##### shared build stage #######################################################

FROM developer-${TARGET_ARCHITECTURE} AS developer

# copy initial epics folder structure
COPY epics /epics

# get and build EPICS base
RUN git clone https://github.com/epics-base/epics-base.git -q --branch ${EPICS_VERSION} --recursive ${EPICS_BASE}
RUN bash /epics/scripts/patch-epics-base.sh
RUN make -C ${EPICS_BASE} -j $(nproc)

# also build the sequencer as it is used by many support modules
RUN wget https://github.com/ISISComputingGroup/EPICS-seq/archive/refs/tags/vendor_2_2_9.tar.gz && \
    tar -xzf vendor*.tar.gz -C ${SUPPORT} && \
    rm vendor*.tar.gz && \
    mv ${SUPPORT}/EPICS-seq* ${SUPPORT}/sncseq && \
    echo EPICS_BASE=${EPICS_BASE} > ${SUPPORT}/sncseq/configure/RELEASE
RUN make -C ${SUPPORT}/sncseq -j $(nproc)


# setup a global python venv and install ibek
RUN python3 -m venv ${VIRTUALENV} && pip install ibek==1.0.0

##### runtime preparation stage ################################################

FROM developer AS runtime_prep

# get the products from the build stage and reduce to runtime assets only
WORKDIR /min_files
RUN bash /epics/scripts/minimize.sh ${EPICS_BASE} ${IOC} $(ls -d ${SUPPORT}/*/)

##### runtime stage ############################################################

FROM environment as runtime

# add runtime system dependencies
RUN apt-get update -y && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    libpython3-stdlib \
    python3-minimal \
    && rm -rf /var/lib/apt/lists/*

# add products from build stage
COPY --from=runtime_prep /min_files /
COPY --from=developer ${VIRTUALENV} ${VIRTUALENV}

