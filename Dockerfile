# EPICS 7 Base Dockerfile

##### shared environment stage #################################################

FROM ubuntu:22.04 AS environment

ENV EPICS_ROOT=/repos/epics
ENV EPICS_BASE=${EPICS_ROOT}/epics-base
ENV EPICS_HOST_ARCH=linux-x86_64
ENV LD_LIBRARY_PATH=${EPICS_BASE}/lib/${EPICS_HOST_ARCH}
ENV VIRTUALENV /venv
ENV PATH=${VIRTUALENV}/bin:${EPICS_BASE}/bin/${EPICS_HOST_ARCH}:${PATH}
ENV SUPPORT ${EPICS_ROOT}/support
ENV IOC ${EPICS_ROOT}/ioc
ENV RTEMS_TOP=/rtems

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

##### developer / build stage ##################################################

FROM devtools AS developer

# pull in RTEMS toolchain and patch files
COPY --from=ghcr.io/epics-containers/rtems-powerpc:1.0.0 ${RTEMS_TOP} ${RTEMS_TOP}
COPY scripts/patch-rtems.sh ${EPICS_ROOT}/patch-base.sh

# PATH makes this venv the default for the container - install ibek in the venv
RUN python3 -m venv ${VIRTUALENV} && \
    pip install ibek==0.9.1

# get and build epics-base and devIocStats
WORKDIR ${SUPPORT}
COPY modules.py *modules.yaml .
RUN python3 modules.py install base.ibek.modules.yaml
RUN python3 modules.py build base.ibek.modules.yaml
COPY epics ${EPICS_ROOT}
RUN make -C ${IOC} && make clean -C ${IOC}

##### runtime preparation stage ################################################

FROM developer AS runtime_prep
ARG TARGET_ARCHITECTURE=linux
ENV TARGET_ARCHITECTURE=${TARGET_ARCHITECTURE}

# get the products from the build stage and reduce to runtime assets only
WORKDIR /min_files
RUN bash ${SUPPORT}/minimize.sh ${EPICS_BASE} ${IOC} $(ls -d ${SUPPORT}/*/)

# add the RTEMS toolchain if needed
RUN if [[ ${TARGET_ARCHITECTURE} == "rtems" ]]; then \
        mv ${RTEMS_TOP} /min_files/${RTEMS_TOP} \
    fi

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

