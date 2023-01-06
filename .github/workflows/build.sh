#!/bin/bash

# A script for building EPICS container images
#
# Note that this is done in bash to make it portable between
# CI frameworks. This approach uses the minimum of GitHub Actions
# features. It is also intended to work locally for testing outside
# of CI.
#

# Notes on podman vs docker buildx
# see https://pythonspeed.com/articles/podman-buildkit/
# podman does not support the same caching buildx at present

# PREREQUISITES: the caller should be authenticated to the
# container registry for push (when PUSH is true)

# work with docker or podman (for local builds)
podman=false
if [ -z $(which docker 2> /dev/null) ] ; then
    podman=true
    alias docker=podman
fi

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

        image_name=${REPOSITORY}-${ARCHITECTURE}-${TARGET}
        args="--build-arg TARGET_ARCHITECTURE=${ARCHITECTURE} --target ${TARGET} -t ${image_name} ."

        if [[ $podman==true ]] ; then
            podman build ${args}
        else
            docker buildx build --cache-to=type=local,dest=${cacheto} \
              --cache-from=type=local,dest=${cachefrom} ${args}
        fi
        # only the first build uses the externally provided cache
        # that way we can avoid indefinitely growning cache
        cachefrom=${cacheto}

        if [[ ${PUSH}==true ]] ; then
            docker push ${image_name}
        fi
    done
done

# overwrite the external cache with our new cache
# this approach means that the cache does not indefinitely grow
rm -rf ${CACHE}
mv ${cacheto} ${CACHE}
