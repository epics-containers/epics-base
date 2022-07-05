##### shared environment stage #################################################

FROM --platform=amd64 ubuntu:22.04 AS environment

ARG TARGETPLATFORM BUILDPLATFORM

RUN echo "TARGET=${TARGETPLATFORM} BUILD=${BUILDPLATFORM}"

# environment
ENV EPICS_ROOT=/repos/epics

WORKDIR ${EPICS_ROOT}

COPY README.md .


##### build stage ##############################################################

FROM environment AS developer

ARG TARGETARCH TARGETPLATFORM TARGETVARIANT TARGETOS BUILDARCH BUILDPLATFORM BUILDVARIANT BUILDOS

RUN echo "--- $TARGETPLATFORM $TARGETARCH $TARGETVARIANT $TARGETOS" | tee target.txt
RUN echo "--- $BUILDPLATFORM $BUILDARCH $BUILDVARIANT $BUILDOS " | tee build.txt


##### runtime stage ############################################################

FROM environment AS runtime

# get the products from the build stage
COPY --from=developer ${EPICS_ROOT} ${EPICS_ROOT}
