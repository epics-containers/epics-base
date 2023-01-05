#!/usr/bin/env bash
RTEMS_KERNEL=${RTEMS_TOP}/rtems
RTEMS_TOOLCHAIN=${RTEMS_TOP}/toolchain

echo "RTEMS_KERNEL = ${RTEMS_KERNEL}" >> configure/CONFIG_SITE.local
echo "RTEMS_TOOLCHAIN = ${RTEMS_TOOLCHAIN}" >> configure/CONFIG_SITE.local
cat configure/CONFIG_SITE.local

cd ${EPICS_ROOT}/epics-base
patch -p1 << EOF
diff --git a/configure/CONFIG_SITE b/configure/CONFIG_SITE
index 03ec6d1..d1d23cc 100644
--- a/configure/CONFIG_SITE
+++ b/configure/CONFIG_SITE
@@ -96,7 +96,7 @@
 # Which target architectures to cross-compile for.
 #  Definitions in configure/os/CONFIG_SITE.<host>.Common
 #  may override this setting.
-CROSS_COMPILER_TARGET_ARCHS=
+CROSS_COMPILER_TARGET_ARCHS=RTEMS-beatnik

 # If only some of your host architectures can compile the
 #  above CROSS_COMPILER_TARGET_ARCHS specify those host
diff --git a/configure/CONFIG_SITE_ENV b/configure/CONFIG_SITE_ENV
index bacbc14..53e9588 100644
--- a/configure/CONFIG_SITE_ENV
+++ b/configure/CONFIG_SITE_ENV
@@ -35,6 +35,8 @@
 #       variable format that VxWorks needs.
 #               https://developer.ibm.com/articles/au-aix-posix/

+EPICS_TZ = "UTC"
+
 # Japan Standard Time, no DST:
 #EPICS_TZ = "JST-9"

@@ -48,7 +50,7 @@
 #EPICS_TZ = "EST5EDT,M3.2.0/2,M11.1.0/2"

 # US Central Standard/Daylight Time:
-EPICS_TZ = "CST6CDT,M3.2.0/2,M11.1.0/2"
+#EPICS_TZ = "CST6CDT,M3.2.0/2,M11.1.0/2"

 # US Mountain Standard/Daylight Time:
 #EPICS_TZ = "MST7MDT,M3.2.0/2,M11.1.0/2"
diff --git a/configure/os/CONFIG.Common.RTEMS-beatnik b/configure/os/CONFIG.Common.RTEMS-beatnik
index b133fd4..94f3c04 100644
--- a/configure/os/CONFIG.Common.RTEMS-beatnik
+++ b/configure/os/CONFIG.Common.RTEMS-beatnik
@@ -11,7 +11,7 @@ GNU_TARGET = powerpc-rtems
 # optimization trouble in postfix.c
 ARCH_DEP_CFLAGS += -DRTEMS_HAS_ALTIVEC
 #will use bootp
-#ARCH_DEP_CFLAGS += -DMY_DO_BOOTP=NULL
+ARCH_DEP_CFLAGS += -DMY_DO_BOOTP=NULL
 ARCH_DEP_CFLAGS += -DHAVE_MOTLOAD
 ARCH_DEP_CFLAGS += -DRTEMS_NETWORK_CONFIG_MBUF_SPACE=2048
 ARCH_DEP_CFLAGS += -DRTEMS_NETWORK_CONFIG_CLUSTER_SPACE=5120
diff --git a/configure/os/CONFIG_SITE.Common.RTEMS b/configure/os/CONFIG_SITE.Common.RTEMS
index 6857dc9..584ec53 100644
--- a/configure/os/CONFIG_SITE.Common.RTEMS
+++ b/configure/os/CONFIG_SITE.Common.RTEMS
@@ -21,12 +21,17 @@
 # APS:
 #RTEMS_VERSION = 4.10.2
 #RTEMS_BASE = /usr/local/vw/rtems/rtems-4.10.2
-#RTEMS_VERSION = 5
-#RTEMS_BASE = /usr/local/vw/rtems/rtems-5.1
+RTEMS_VERSION = 5
+# We will define RTEMS_KERNEL and RTEMS_TOOLCHAIN in CONFIG_SITE.local
+RTEMS_BASE = $(RTEMS_KERNEL)
+OP_SYS_CFLAGS += -DRTEMS_NETWORK_CONFIG_DNS_DOMAINNAME=cs.diamond.ac.uk
+# This allows using deprecated (non-typed rset)
+OP_SYS_CFLAGS += -Wno-error=deprecated-declarations
+OP_SYS_CFLAGS += -D__NO_HOTSWAP__

 # Cross-compile toolchain in $(RTEMS_TOOLS)/bin
 #
-RTEMS_TOOLS = $(RTEMS_BASE)
+RTEMS_TOOLS = $(RTEMS_TOOLCHAIN)

 # Link Generic System loadable objects instead of full executable.
 #
diff --git a/modules/libcom/RTEMS/rtems_netconfig.c b/modules/libcom/RTEMS/rtems_netconfig.c
index 38fb6bf..a5d04a3 100644
--- a/modules/libcom/RTEMS/rtems_netconfig.c
+++ b/modules/libcom/RTEMS/rtems_netconfig.c
@@ -93,13 +93,20 @@ static struct rtems_bsdnet_ifconfig e3c509_driver_config = {
 #  endif
 # endif

-static struct rtems_bsdnet_ifconfig netdriver_config = {
-    RTEMS_BSP_NETWORK_DRIVER_NAME,      /* name */
+/* add this to configure the second ethernet port */
+static struct rtems_bsdnet_ifconfig gfedriver_config = {
+    "gfe1",      /* name */
     RTEMS_BSP_NETWORK_DRIVER_ATTACH,    /* attach function */
 #if RTEMS_VERSION_INT<=VERSION_INT(4,10,0,0)
     &loopback_config,                   /* link to next interface */
 #endif
 };
+
+static struct rtems_bsdnet_ifconfig netdriver_config = {
+    RTEMS_BSP_NETWORK_DRIVER_NAME,      /* name */
+    RTEMS_BSP_NETWORK_DRIVER_ATTACH,    /* attach function */
+    &gfedriver_config
+};
 #define FIRST_DRIVER_CONFIG &netdriver_config

 #endif
EOF