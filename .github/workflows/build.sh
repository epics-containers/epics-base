#!/bin/bash

# A script for building EPICS container images
#
# Note that this is done in bash to make it portable between
# CI frameworks. This approach uses the minimum of GitHub Actions
# features. It is also intended to work locally for testing outside
# of CI.
#
# PREREQUISITES: the caller should be authenticated to the
# container registry for push (when PUSH is true)
#

# export PODMAN=true if you want to use it for local builds with no push
if [[ ${PODMAN} == "true" ]] ; then
    alias docker=podman
else
    # setup a buildx driver
    docker buildx create --use
fi

set -ex

# Provide some defaults for the controlling Environment Variables.
# Supported ARCHTECTURES are linux rtems
ARCHITECTURES=${ARCHITECTURES:-linux}
REPOSITORY=${REPOSITORY:-localtest}
CACHE=${CACHE:-/tmp/.docker-cache}
PUSH=${PUSH:-false}
TAG=${TAG:-latest}

cachefrom=${CACHE}
cacheto=/tmp/.buildx-new
mkdir -p ${cacheto}

for ARCHITECTURE in ${ARCHITECTURES}; do
    for TARGET in developer runtime; do

        image_name=ghcr.io/${REPOSITORY}-${ARCHITECTURE}-${TARGET}:${TAG}
        args="--build-arg TARGET_ARCHITECTURE=${ARCHITECTURE} --target ${TARGET} ."

        if [[ ${PUSH} == true ]] ; then
            args="--push ${image_name} "${args}
        fi

        if [[ ${PODMAN} == "true" ]] ; then
            podman build ${args}
        else
            docker buildx build --cache-to=type=local,dest=${cacheto} \
              --cache-from=type=local,src=${cachefrom} ${args}
        fi
        # only the first build uses the externally provided cache
        # that way we can avoid indefinitely growning cache
        cachefrom=${cacheto}
    done
done

# overwrite the external cache with our new cache
# this approach means that the cache does not indefinitely grow
rm -rf ${CACHE}
mv ${cacheto} ${CACHE}
