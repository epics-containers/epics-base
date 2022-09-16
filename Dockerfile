# EPICS 7 Base Dockerfile

##### shared environment stage #################################################
ARG TARGET_ARCHITECTURE=linux

FROM ubuntu:22.04 AS environment

ENV EPICS_VERSION=R7.0.6.1
ARG TARGET_ARCHITECTURE
# EPICS BASE Envrionment
ENV TARGET_ARCHITECTURE=${TARGET_ARCHITECTURE}
ENV EPICS_ROOT=/repos/epics
ENV EPICS_BASE=${EPICS_ROOT}/epics-base
ENV EPICS_HOST_ARCH=linux-x86_64
ENV PATH=${EPICS_BASE}/bin/${EPICS_HOST_ARCH}:${PATH}
ENV LD_LIBRARY_PATH=${EPICS_BASE}/lib/${EPICS_HOST_ARCH}
# Python Virtual Environment
ENV VIRTUALENV /venv
ENV PATH=${VIRTUALENV}/bin:$PATH
# IOC Environment
ENV SUPPORT ${EPICS_ROOT}/support
ENV IOC ${EPICS_ROOT}/ioc

WORKDIR ${EPICS_ROOT}


##### setup shared developer tools stage #######################################

FROM environment AS devtools

# install build tools and utilities
RUN apt-get update -y && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    build-essential \
    busybox \
    diffutils \
    git \
    libc-dev-bin \
    python3-dev \
    python3-pip \
    python3-venv \
    re2c \
    rsync \
    ssh-client \
    && rm -rf /var/lib/apt/lists/* \
    && busybox --install

# container venv. Always used because PATH will pick up its python executable
RUN python3 -m venv ${VIRTUALENV} && \
    pip install ibek

##### unique developer setup for linux soft iocs ###############################

FROM devtools AS developer-linux

COPY scripts/patch-linux.sh ${EPICS_ROOT}/patch-base.sh


##### unique developer setup for rtems iocs ####################################

FROM devtools AS developer-rtems

ENV RTEMS_TOP=/rtems

# pull in RTEMS toolchain and patch files
COPY --from=ghcr.io/epics-containers/rtems-powerpc:1.0.0 ${RTEMS_TOP} ${RTEMS_TOP}
COPY scripts/patch-rtems.sh ${EPICS_ROOT}/patch-base.sh
COPY scripts/rtems-epics-base.patch ${EPICS_ROOT}


##### shared build stage #######################################################

FROM developer-${TARGET_ARCHITECTURE} AS developer

# get the epics-base source including PVA submodules
RUN git config --global advice.detachedHead false && \
    git clone --recursive --depth 1 -b ${EPICS_VERSION} https://github.com/epics-base/epics-base.git 

# build epics-base
RUN bash patch-base.sh && \
    make -j $(nproc) -C ${EPICS_BASE} && \
    make clean -j $(nproc) -C ${EPICS_BASE}

# add fundamental support modules and empty IOC
WORKDIR ${SUPPORT}
COPY scripts/module.py .
RUN python3 module.py init
RUN python3 module.py add-tar http://www-csr.bessy.de/control/SoftDist/sequencer/releases/seq-{TAG}.tar.gz seq SNCSEQ 2.2.9
RUN python3 module.py add epics-modules iocStats DEVIOCSTATS 3.1.16
COPY epics ${EPICS_ROOT}
RUN make -C ${IOC} && make clean -C ${IOC}

##### runtime preparation stage ################################################

FROM developer AS runtime_prep

# get the products from the build stage and reduce to runtime assets only 
WORKDIR /min_files
RUN bash ${SUPPORT}/minimize.sh ${EPICS_BASE} ${IOC} $(ls -d ${SUPPORT}/*/)

##### runtime stage ############################################################

FROM environment as runtime

RUN apt-get update -y && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    libpython3-stdlib \
    python3-minimal \
    && rm -rf /var/lib/apt/lists/* 

COPY --from=runtime_prep /min_files /
COPY --from=devtools ${VIRTUALENV} ${VIRTUALENV}

