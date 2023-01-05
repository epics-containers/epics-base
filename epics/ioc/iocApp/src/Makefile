TOP = ../..
include $(TOP)/configure/CONFIG

PROD_IOC = ioc
DBD += ioc.dbd
ioc_DBD += base.dbd
ioc_DBD += devIocStats.dbd
ioc_SRCS += ioc_registerRecordDeviceDriver.cpp
ioc_LIBS += devIocStats
ioc_LIBS += $(EPICS_BASE_IOC_LIBS)
ioc_SRCS += iocMain.cpp

include $(TOP)/configure/RULES