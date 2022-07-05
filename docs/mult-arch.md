# Multi Arch for RTEMS


I would like to use multi arch, cross compiled builds for supporting RTEMS
and linux soft IOCs in the same Dockerfiles.

This way we get a matrix like so:

<img src="images/Multi Arch.excalidraw.png"
     alt="MultiArch"
     style="margin-right: 10px; width: 600px" />


## Why Multi Arch, not just more Stages?

It is **important** that we use multi-arch instead of a 4 stage build.

With the 2 architectures we want to run mostly the SAME steps in the Dockerfile
just with the environment set up differently. With the two stages 'developer'
and 'runtime' we have a thread of separate stages throughout the image
hierarchy that run distinctly different steps.

## References

A good article on multi arch is here:
https://cloudolife.com/2022/03/05/Infrastructure-as-Code-IaC/Container/Docker/Docker-buildx-support-multiple-architectures-images/

But the above is going to a lot of trouble because it wants to run emulators.
We want to run with the same BUILDARCH but switch TARGETARCH and we also want
a custom TARGETARCH named something like 'rtems/powerpc'.

This article seems to describe a closer scenario:
https://www.docker.com/blog/faster-multi-platform-builds-dockerfile-cross-compilation-guide/

## Example

I have this example working with docker. (It looks like podman does now support
multi arch but slightly differently)



