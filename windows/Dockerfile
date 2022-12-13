# escape=`

# Setting up a Windows Build Container for EPICS
# Based on information from:
#   https://github.com/Microsoft/vs-Dockerfiles
#   https://docs.epics-controls.org/projects/how-tos/en/latest/getting-started/installation-windows.html

ARG FROM_IMAGE=mcr.microsoft.com/windows/servercore:ltsc2022
FROM ${FROM_IMAGE}

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


# Use cygwin to get bash commands and EPICS build dependencies of perl, zip and make
ADD https://www.cygwin.com/setup-x86_64.exe C:\install-cygwin.exe
RUN  C:\install-cygwin.exe -q -P bash,bash-completion,git,make,perl,tar,vim,wget,zip -s http://cygwin.mirror.uk.sargasso.net
ENV PATH=\cygwin64\bin
# Add the package installer apt-cyg
ADD https://raw.githubusercontent.com/transcode-open/apt-cyg/master/apt-cyg C:\TEMP\apt-cyg
RUN install C:\TEMP\apt-cyg /bin

# NOTE:
# https://docs.epics-controls.org/projects/how-tos/en/latest/getting-started/installation-windows.html
# Above URL recommends MSYS2 instead of Cygwin - TODO review this choice

# I'm having issues with the powershell entrypoint in vs-Dockerfiles
# use CMD with vcvars64.bat instead
CMD [ "cmd.exe /K /BuildTools/VC/Auxiliary/Build/vcvars64.bat" ]
# ENTRYPOINT ["C:\BuildTools\Common7\Tools\VsDevCmd.bat", "&&", "powershell.exe", "-NoLogo", "-ExecutionPolicy", "Bypass"]
