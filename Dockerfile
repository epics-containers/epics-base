# EPICS 7 Base Dockerfile

##### shared environment stage #################################################

FROM ubuntu:22.04 AS environment
# 20.04 latest LTS: Canonical will support it with updates until April 2025
# with extended security updates until April 2030

# environment
ENV EPICS_ROOT=/repos/epics
ENV EPICS_BASE=${EPICS_ROOT}/epics-base
ENV SUPPORT ${EPICS_ROOT}/support
ENV IOC ${EPICS_ROOT}/ioc
ENV EPICS_HOST_ARCH=linux-x86_64
ENV PATH="${EPICS_BASE}/bin/${EPICS_HOST_ARCH}:${PATH}"
ENV LD_LIBRARY_PATH=${EPICS_BASE}/lib/linux-x86_64

WORKDIR ${EPICS_ROOT}

##### build stage ##############################################################

FROM environment AS developer

ARG EPICS_VERSION=R7.0.6.1

# install build tools and utilities
RUN apt-get update -y && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    build-essential \
    busybox-static \
    git \
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

##### runtime stage ############################################################

FROM environment AS runtime

# get the products from the build stage
COPY --from=developer ${EPICS_ROOT} ${EPICS_ROOT}
