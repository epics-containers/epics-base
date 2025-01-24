#!/bin/bash

# A script to extract the runtime files from the developer stage for use in
# the runtime stage.

# The first argument is the destination directory for the runtime files.
DEST=${1}

cd /

paths="
epics/epics-base/bin
epics/epics-base/lib
venv
epics/support/configure
epics/support/pvxs/db
epics/support/pvxs/bin
epics/support/pvxs/lib
"

for i in ${paths} ; do
    # skip if the path does not exist
    if [ ! -d ${i} ]; then
        continue
    fi

    # strip any binaries
    strip $(find ${i}) 2>/dev/null

    # make sure the path to the parent exists
    if [ ! -d ${DEST}/$(dirname ${i}) ]; then
        mkdir -p ${DEST}/$(dirname ${i})
    fi

    # move the directory to the new location
    mv ${i} ${DEST}/${i}
done
