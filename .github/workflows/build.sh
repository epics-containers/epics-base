#/bin/bash

# Launcher script to get the latest version of podman and use it to
# build this repo's container image matrix
#
# podman is chosen as the container image builder because caching to
# GHCR works well. We get the latest version of podman inside a container
# because GHA runners only have podman 3.4 (ships with Ubuntu 22.04)

# Its as simple as this :-)
#   Github Actions is launching a virtual machine with Ubuntu 22.04
#   In GHA we run podman 3.4
#   podman runs a container with podman 4.3.1 inside
#   podman inside builds our container images and pushes them to GHCR
#       it also does caching to GHCR

THISDIR=$(dirname $0)

podman run -v $(pwd):$(pwd) -w $(pwd) \
       -e REGISTRY -e REPOSITORY -e USER -e TOKEN \
       -e ARCHITECTURES -e TAG -e PUSH \
       --cap-add=sys_admin --cap-add mknod --device=/dev/fuse \
       --security-opt seccomp=unconfined --security-opt label=disable \
       quay.io/podman/stable bash $THISDIR/build2.sh
