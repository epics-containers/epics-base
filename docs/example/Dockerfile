##### shared environment stage #################################################

FROM --platform=${BUILDPLATFORM} ubuntu:22.04 AS environment

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

ENV TARGET=developer
ENV TARGETPLATFORM=${TARGETPLATFORM}

CMD echo I am the ${TARGET} target for ${TARGETPLATFORM}

##### runtime stage ############################################################

FROM environment AS runtime

ARG TARGETARCH TARGETPLATFORM
ENV TARGET=runtime
ENV TARGETPLATFORM=${TARGETPLATFORM}

# get the products from the build stage
COPY --from=developer ${EPICS_ROOT} ${EPICS_ROOT}

CMD echo I am the ${TARGET} target for ${TARGETPLATFORM}