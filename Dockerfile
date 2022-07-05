# EPICS 7 Base Dockerfile

##### shared environment stage #################################################
ARG TARGET_ARCHITECTURE=linux

FROM ubuntu:22.04 AS environment

# environment
ENV EPICS_ROOT=/repos/epics
ENV EPICS_BASE=${EPICS_ROOT}/epics-base
ENV SUPPORT ${EPICS_ROOT}/support
ENV IOC ${EPICS_ROOT}/ioc
ENV PYTHON_PKG ${EPICS_ROOT}/python
ENV PYTHONPATH=${PYTHON_PKG}/local/lib/python3.10/dist-packages/
ENV EPICS_HOST_ARCH=linux-x86_64
ENV PATH="${EPICS_BASE}/bin/${EPICS_HOST_ARCH}:${PYTHON_PKG}/local/bin:${PATH}"
ENV LD_LIBRARY_PATH=${EPICS_BASE}/lib/linux-x86_64

WORKDIR ${EPICS_ROOT}

# global installs for developer and runtime
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    libpython3-stdlib \
    python3-minimal \
    && rm -rf /var/lib/apt/lists/*

FROM environment AS environment-linux

RUN echo "TODO: Unique Linux setup goes here"

FROM environment AS environment-rtems

RUN echo "TODO: Unique RTEMS setup goes here"

##### build stage ##############################################################

FROM environment-${TARGET_ARCHITECTURE} AS developer

ARG EPICS_VERSION=R7.0.6.1

# install build tools and utilities
RUN apt-get update -y && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    build-essential \
    busybox \
    git \
    python3-pip \
    rsync \
    ssh-client \
    && rm -rf /var/lib/apt/lists/*

# get the epics-base source including PVA submodules - minimizing image size
RUN git config --global advice.detachedHead false && \
    git clone --recursive --depth 1 -b ${EPICS_VERSION} https://github.com/epics-base/epics-base.git && \
    sed -i 's/\(^OPT.*\)-g/\1-g0/' ${EPICS_BASE}/configure/os/CONFIG_SITE.linux-x86_64.linux-x86_64

# build
RUN make -j -C ${EPICS_BASE} && \
    make clean -j -C ${EPICS_BASE}

# resources for all support modules
COPY support ${SUPPORT}/ 
RUN pip install --prefix=${PYTHON_PKG} -r ${SUPPORT}/requirements.txt

##### runtime stage ############################################################

FROM environment AS runtime

# get the products from the build stage
COPY --from=developer ${EPICS_ROOT} ${EPICS_ROOT}
