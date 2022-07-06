# EPICS 7 Base Dockerfile

##### shared environment stage #################################################
ARG TARGET_ARCHITECTURE=linux

FROM ubuntu:22.04 AS environment

ENV EPICS_VERSION=R7.0.6.1
ARG TARGET_ARCHITECTURE
ENV TARGET_ARCHITECTURE=${TARGET_ARCHITECTURE}
ENV EPICS_ROOT=/repos/epics
ENV EPICS_BASE=${EPICS_ROOT}/epics-base
ENV EPICS_HOST_ARCH=linux-x86_64
ENV PATH="${EPICS_BASE}/bin/${EPICS_HOST_ARCH}:${PATH}"
ENV LD_LIBRARY_PATH=${EPICS_BASE}/lib/${EPICS_HOST_ARCH}

WORKDIR ${EPICS_ROOT}

##### setup shared developer tools stage #######################################

FROM environment AS devtools

# install build tools and utilities
RUN apt-get update -y && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    build-essential \
    busybox \
    git \
    rsync \
    ssh-client \
    && rm -rf /var/lib/apt/lists/*


##### unique developer setup for linux soft iocs ###############################

FROM devtools AS developer-linux

COPY scripts/patch-linux.sh patch-base.sh


##### unique developer setup for rtems iocs ####################################

FROM devtools AS developer-rtems

ENV RTEMS_TOP=/rtems
RUN mkdir -p ${RTEMS_TOP}

# pull and build the rtems cross compiler and dependencies
COPY scripts/install-rtems.sh ${RTEMS_TOP}
RUN cd ${RTEMS_TOP} && if [ "${TARGET_ARCHITECTURE}" = "rtems" ] ; then \
    ./install-rtems.sh ; fi

# copy patch files for rtems
COPY scripts/patch-rtems.sh ${EPICS_ROOT}/patch-base.sh
COPY scripts/rtems-epics-base.patch ${EPICS_ROOT}


##### shared build stage #######################################################

FROM developer-${TARGET_ARCHITECTURE} AS developer

# get the epics-base source including PVA submodules
# sed command minimizes image size by removing symbols (for review)
RUN git config --global advice.detachedHead false && \
    git clone --recursive --depth 1 -b ${EPICS_VERSION} \
    https://github.com/epics-base/epics-base.git && \
    sed -i 's/\(^OPT.*\)-g/\1-g0/' \
    ${EPICS_BASE}/configure/os/CONFIG_SITE.linux-x86_64.linux-x86_64

# build
RUN bash patch-base.sh && \
    make -j $(nproc) -C ${EPICS_BASE} && \
    make clean -j $(nproc) -C ${EPICS_BASE}

##### runtime stage ############################################################

FROM environment AS runtime

# get the products from the build stage
COPY --from=developer ${EPICS_ROOT} ${EPICS_ROOT}
