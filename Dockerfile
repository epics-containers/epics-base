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

FROM environment-$TARGETARCH AS environment

ARG TARGET_ARCHITECTURE
ENV TARGET_ARCHITECTURE=${TARGET_ARCHITECTURE}
ENV EPICS_ROOT=/repos/epics
ENV EPICS_BASE=${EPICS_ROOT}/epics-base
ENV LD_LIBRARY_PATH=${EPICS_BASE}/lib/${EPICS_HOST_ARCH}
ENV VIRTUALENV /venv
ENV PATH=${VIRTUALENV}/bin:${EPICS_BASE}/bin/${EPICS_HOST_ARCH}:${PATH}
ENV SUPPORT ${EPICS_ROOT}/support
ENV IOC ${EPICS_ROOT}/ioc
ENV RTEMS_TOP=/rtems


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

# this script is used to output the ibek IOC schema for the hosting container
COPY ctools/ioc-schema /usr/local/bin

##### unique developer setup for linux soft iocs ###############################

FROM devtools AS developer-linux

# nothing additional to do for linux

##### unique developer setup for rtems iocs ####################################

FROM devtools AS developer-rtems

# pull in RTEMS toolchain
COPY --from=ghcr.io/epics-containers/rtems-powerpc:1.0.0 ${RTEMS_TOP} ${RTEMS_TOP}

##### shared build stage #######################################################

FROM developer-${TARGET_ARCHITECTURE} AS developer

# copy in IOC template
COPY epics ${EPICS_ROOT}

# PATH makes this venv the default for the container - install ibek in the venv
RUN python3 -m venv ${VIRTUALENV} && \
    pip install ibek==0.9.4

# get and build epics-base and essential support modules
WORKDIR /ctools
# use partial copies of ctools at each step to protect the build cache
COPY ctools/modules.py ctools/*epics-base* /ctools
RUN python3 modules.py install EPICS_BASE R7.0.7 github.com/epics-base/epics-base.git --patch patch-epics-base.sh --path ${EPICS_BASE} --git_args --recursive
RUN make -C ${EPICS_BASE} -j $(nproc)

RUN python3 modules.py install SNCSEQ 2.2.6 http://www-csr.bessy.de/control/SoftDist/sequencer/releases/seq-{TAG}.tar.gz
RUN make -C ${SUPPORT}/sncseq -j $(nproc)

COPY ctools/*deviocstats* /ctools
RUN python3 modules.py install DEVIOCSTATS 3.1.16 github.com/epics-modules/iocStats.git --patch patch-deviocstats.sh
RUN make -C ${SUPPORT}/deviocstats -j $(nproc)

# build generic IOC
COPY ctools/patch-ioc.sh /ctools
RUN bash patch-ioc.sh
RUN make -C ${IOC} && make clean -C ${IOC}

# this script is for the next target
# but we copy it here so that all developer derived images have it too
COPY ctools/minimize.sh /ctools

##### runtime preparation stage ################################################

FROM developer AS runtime_prep

# get the products from the build stage and reduce to runtime assets only
WORKDIR /min_files
RUN bash /ctools/minimize.sh ${EPICS_BASE} ${IOC} $(ls -d ${SUPPORT}/*/)

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

