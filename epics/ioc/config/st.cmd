# EXAMPLE IOC Instance to demonstrate the ADSimDetector Generic IOC

cd "$(TOP)"

dbLoadDatabase "dbd/ioc.dbd"
ioc_registerRecordDeviceDriver(pdbbase)

# start IOC shell
iocInit

