# we keep the sncseq source in our own epics-base repo because
# the original source has been removed for the moment
# (BESSY Hack: https://www.helmholtz.de/en/newsroom/bessy-ii-back-in-operation-after-cyber-attack-on-helmholtz-zentrum-berlin-hzb/)

cd /tmp

wget https://github.com/epics-containers/epics-base/raw/dev/vendor_2_2_9.tar.gz
tar -xzf vendor*.tar.gz -C ${SUPPORT}
rm vendor*.tar.gz
mv ${SUPPORT}/EPICS-seq* ${SUPPORT}/sncseq
echo EPICS_BASE=${EPICS_BASE} > ${SUPPORT}/sncseq/configure/RELEASE
