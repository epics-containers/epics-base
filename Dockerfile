# escape=`

# Setting up a Windows Build Container for EPICS
# Based on information from:
#   https://github.com/Microsoft/vs-Dockerfiles
#   https://docs.epics-controls.org/projects/how-tos/en/latest/getting-started/installation-windows.html

ARG FROM_IMAGE=mcr.microsoft.com/windows/servercore:ltsc2022
FROM ${FROM_IMAGE} as developer

# Reset the shell.
SHELL ["cmd", "/S", "/C"]

# Set up environment to collect install errors.
COPY Install.cmd C:\TEMP\
ADD https://aka.ms/vscollect.exe C:\TEMP\collect.exe

# Download channel for fixed install.
ARG CHANNEL_URL=https://aka.ms/vs/17/release/channel
ADD ${CHANNEL_URL} C:\TEMP\VisualStudio.chman

# Download and install Build Tools for Visual Studio 2022 for native desktop workload.
ADD https://aka.ms/vs/17/release/vs_buildtools.exe C:\TEMP\vs_buildtools.exe
RUN C:\TEMP\Install.cmd C:\TEMP\vs_buildtools.exe --quiet --wait --norestart --nocache `
    --channelUri C:\TEMP\VisualStudio.chman `
    --installChannelUri C:\TEMP\VisualStudio.chman `
    --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended`
    --installPath C:\BuildTools

# TODO relplace these ADD with wget or similar

# Use cygwin to get bash commands
ADD https://www.cygwin.com/setup-x86_64.exe C:\install-cygwin.exe
RUN  C:\install-cygwin.exe -q -P bash,bash-completion,git,tar,unzip,vim,wget,zip -s http://cygwin.mirror.uk.sargasso.net
RUN setx path "%path%;"\cygwin64\bin"

# strawberry perl
ADD https://strawberryperl.com/download/5.32.1.1/strawberry-perl-5.32.1.1-64bit.zip C:\TEMP\strawberry-perl.zip
RUN unzip C:\TEMP\strawberry-perl.zip -d C:\strawberry-perl
RUN setx path "C:\strawberry-perl\perl\bin;%path%"
RUN c:\strawberry-perl\relocation.pl.bat

# Get EPICS BASE source
WORKDIR repos/epics/
RUN git clone https://github.com/epics-base/epics-base.git
COPY CONFIG_SITE.local epics-base/configure/CONFIG_SITE.local

RUN /BuildTools/VC/Auxiliary/Build/vcvars64.bat && cd epics-base && gmake

# I'm having issues with the powershell entrypoint in vs-Dockerfiles
# use CMD with vcvars64.bat instead
CMD [ "cmd" ]
# this is failing - manually run instead for now
#ENTRYPOINT ["/K", "/BuildTools/VC/Auxiliary/Build/vcvars64.bat"]
