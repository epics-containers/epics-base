# EPICS 7 Base Dockerfile

#  build args
#   TARGET_ARCHITECTURE: the epics cross compile target platform
#     note that linux-x86_64 is shortened to linux and is the default
#   EPICS_HOST_ARCH: the epics host architecture name
#   BASE_IMAGE: can be used to bring in cross compilation tools

ARG BASE_IMAGE=ubuntu:22.04

##### shared environment stage #################################################
FROM ${BASE_IMAGE} AS environment

ARG TARGET_ARCHITECTURE=linux-x86_64
ARG EPICS_HOST_ARCH=linux-x86_64

ENV TARGET_ARCHITECTURE=${TARGET_ARCHITECTURE}
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

COPY requirements.txt /requirements.txt
RUN python3 -m venv ${VIRTUALENV} && pip install -r /requirements.txt

##### runtime preparation stage ################################################
FROM developer AS runtime_prep

# get the products from the build stage and reduce to runtime assets only
RUN ibek ioc extract-runtime-assets /assets --no-defaults /venv

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

