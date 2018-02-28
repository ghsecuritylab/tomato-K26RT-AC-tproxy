#
# Generic portion of the Broadcom wl driver makefile
#
# input: O_TARGET, CONFIG_WL_CONF and wl_suffix
# output: obj-m, obj-y
#
# $Id: wl_generic.mk,v 1.10 2011-01-21 22:12:09 $
#

#REBUILD_WL_MODULE=$(shell if [ -d "$(src)/$(SRCBASE)/wl/sys" -a "$(REUSE_PREBUILT_WL)" != "1" ]; then echo 1; else echo 0; fi)
REBUILD_WL_MODULE=0

# If source directory (src/wl/sys) exists and REUSE_PREBUILT_WL is undefined, 
# then build inside $(SRCBASE)/wl/sys, otherwise use pre-builts
ifeq ($(REBUILD_WL_MODULE),1)

    # Get the source files and flags from the specified config file
    # (Remove config's string quotes before trying to use the file)
    ifeq ($(CONFIG_WL_CONF),)
         $(error var_vlist($(VLIST)) var_config_wl_use($(shell env|grep CONFIG_WL_USE)))
         $(error CONFIG_WL_CONF is undefined)
    endif

    WLCONFFILE := $(strip $(subst ",,$(CONFIG_WL_CONF))) 
    WLCFGDIR   := $(src)/$(SRCBASE)/wl/config

    # define OS flag to pick up wl osl file from wl.mk
    WLLX=1
    ifdef CONFIG_PLC
        PLC=1
    endif
    ifdef CONFIG_DPSTA
        DPSTA=1
    endif
    PKTC=1
    include $(WLCFGDIR)/$(WLCONFFILE)
    include $(WLCFGDIR)/wl.mk

    ifeq ($(WLCLMAPI),1)
        WLAN_ComponentsInUse := bcmwifi clm
        include $(src)/$(SRCBASE)/makefiles/WLAN_Common.mk
    endif
    
    ifeq ($(WLFILES_SRC),)
         $(error WLFILES_SRC is undefined in $(WLCFGDIR)/$(WLCONFFILE))
    endif
    
    ifeq ($(WLCLMAPI),1)
    $(call WLAN_GenClmCompilerRule,$(src)/$(SRCBASE)/wl/clm/src,$(src)/$(SRCBASE),--ccrev all)
    clean-files += $(SRCBASE)/wl/clm/src/wlc_clm_data.c
    endif
    
    # need -I. to pick up wlconf.h in build directory
   
    ifeq ($(CONFIG_WL_ALL_PASSIVE_ON),y)
    EXTRA_CFLAGS    += -DWL_ALL_PASSIVE_ON -DWL_ALL_PASSIVE
    else
    ifeq ($(CONFIG_WL_ALL_PASSIVE_RUNTIME),y)
    EXTRA_CFLAGS    += -DWL_ALL_PASSIVE
    endif
    endif
    EXTRA_CFLAGS += -DDMA $(WLFLAGS) -I$(src) -I$(src)/.. -I$(src)/$(SRCBASE)/wl/linux \
		    -I$(src)/$(SRCBASE)/wl/sys $(WLAN_ComponentIncPath) -Werror

    ifneq ("$(CONFIG_CC_OPTIMIZE_FOR_SIZE)","y")
         EXTRA_CFLAGS += -finline-limit=2048
    endif
    
    # include path for dpsta.h
    EXTRA_CFLAGS += -I$(src)/$(SRCBASE)/router/dpsta

    # Build the phy source files iff -DPHY_HAL is present.
    ifneq ($(findstring PHY_HAL,$(WLFLAGS)),)
        EXTRA_CFLAGS += -I$(src)/$(SRCBASE)/wl/phy
    else
	WLFILES_SRC := $(filter-out src/wl/phy/%,$(WLFILES_SRC))
    endif

    # The paths in WLFILES_SRC need a bit of adjustment.
    WL_OBJS := $(sort $(patsubst %.c,%.o,$(addprefix $(SRCBASE)/,$(patsubst src/%,%,$(WLFILES_SRC)))))

    # wl-objs is for linking to wl.o
    $(TARGET)-objs := $(WLCONF_O) $(WL_OBJS)
    obj-$(CONFIG_WL) := $(TARGET).o

else # SRCBASE/wl/sys doesn't exist

    # Otherwise, assume prebuilt object module(s) in src/wl/linux directory
    prebuilt := wl_$(wl_suffix).o
    $(TARGET)-objs := $(SRCBASE)/wl/linux/$(prebuilt)
    obj-$(CONFIG_WL) := $(TARGET).o

    ifeq ("$(CONFIG_WL_USBAP)","y")
        wl_high-objs := $(SRCBASE)/wl/linux/wl_high.o
        obj-m += wl_high.o
    endif
endif


#WL_CONF_H: wlconf.h

UPDATESH   := $(WLCFGDIR)/diffupdate.sh

WLTUNEFILE ?= wltunable_lx_router.h

$(obj)/$(WLCONF_O): $(obj)/$(WLCONF_H) FORCE

$(obj)/$(WLCONF_H): $(WLCFGDIR)/$(WLTUNEFILE) FORCE
	[ ! -f $@ ] || chmod +w $@
	@echo "check and update config file"
	@echo $(if $(VLIST),"VLIST          = $(VLIST)")
	@echo "CONFIG_WL_CONF = $(CONFIG_WL_CONF)"
	@echo "WLTUNEFILE     = $(WLTUNEFILE)"
	cp $< wltemp
	$(UPDATESH) wltemp $@

FORCE:

clean-files += $(SRCBASE)/wl/sys/*.o $(SRCBASE)/wl/phy/*.o $(SRCBASE)/wl/sys/.*.*.cmd $(SRCBASE)/wl/phy/.*.*.cmd $(WLCONF_H) $(WLCONF_O)