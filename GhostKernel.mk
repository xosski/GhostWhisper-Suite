# Makefile for GhostKernel module
# Build system integration for GhostWhisper Suite

obj-m += ghostkernel.o
ghostkernel-objs := GhostKernel.o

# Kernel build directory
KDIR := /lib/modules/$(shell uname -r)/build

# Module build directory
PWD := $(shell pwd)

# Default target
all: ghostkernel.ko

# Build the kernel module
ghostkernel.ko: GhostKernel.c
	$(MAKE) -C $(KDIR) M=$(PWD) modules

# Clean build artifacts
clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean
	rm -f *.o *.ko *.mod.c *.mod *.order *.symvers .*.cmd
	rm -rf .tmp_versions

# Install module (requires root)
install: ghostkernel.ko
	sudo cp ghostkernel.ko /lib/modules/$(shell uname -r)/extra/
	sudo depmod -a

# Uninstall module
uninstall:
	sudo rm -f /lib/modules/$(shell uname -r)/extra/ghostkernel.ko
	sudo depmod -a

# Load module
load: ghostkernel.ko
	sudo insmod ghostkernel.ko

# Unload module  
unload:
	sudo rmmod ghostkernel || sudo rmmod usbmon

# Check if module is loaded
status:
	lsmod | grep -E "(ghostkernel|usbmon)" || echo "Module not loaded"
	ls -la /dev/usbmon 2>/dev/null || echo "Device not found"

# Development targets
dev-build: clean all

dev-reload: unload load

.PHONY: all clean install uninstall load unload status dev-build dev-reload
