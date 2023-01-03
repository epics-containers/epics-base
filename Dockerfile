# EPICS 7 Base Dockerfile

##### shared environment stage #################################################
ARG TARGET_ARCHITECTURE=linux

# RTEMS build imcompatible with python2 from ubuntu:22.04
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
# IOC Environment
ENV PYTHON_PKG ${EPICS_ROOT}/python
ENV PYTHONPATH=${PYTHON_PKG}/local/lib/python3.10/dist-packages/
ENV PATH=${PYTHON_PKG}/local/bin:${PATH}
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
    rsync \
    ssh-client \
    && rm -rf /var/lib/apt/lists/*


##### unique developer setup for linux soft iocs ###############################

FROM devtools AS developer-linux

COPY scripts/patch-linux.sh ${EPICS_ROOT}/patch-base.sh


##### unique developer setup for rtems iocs ####################################

FROM devtools AS developer-rtems

ENV RTEMS_TOP=/rtems

# pull in RTEMS toolchain
COPY --from=ghcr.io/epics-containers/rtems-powerpc:1.0.0 ${RTEMS_TOP} ${RTEMS_TOP}

# copy patch files for rtems
COPY scripts/patch-rtems.sh ${EPICS_ROOT}/patch-base.sh
COPY scripts/rtems-epics-base.patch ${EPICS_ROOT}


##### shared build stage #######################################################

FROM developer-${TARGET_ARCHITECTURE} AS developer

# get the epics-base source including PVA submodules
# sed command minimizes image size by removing symbols (for review)
RUN git config --global advice.detachedHead false && \
    git clone --recursive --depth 1 -b ${EPICS_VERSION} https://github.com/epics-base/epics-base.git

# build
RUN bash patch-base.sh && \
    make -j $(nproc) -C ${EPICS_BASE} && \
    make clean -j $(nproc) -C ${EPICS_BASE}

COPY scripts/minimize.sh ${EPICS_ROOT}

##### runtime preparation stage ################################################

FROM developer AS runtime_prep

# get the products from the build stage and reduce to runtime assets only
RUN bash ${EPICS_ROOT}/minimize.sh ${EPICS_ROOT} /MIN_ROOT


##### runtime stage ############################################################

FROM environment as runtime

COPY --from=runtime_prep /MIN_ROOT ${EPICS_ROOT}

