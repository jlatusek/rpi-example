#!/usr/bin/make
.ONESHELL:
.PHONY: all clean mount umount losetup

IMG_DIR := img
SYSROOT := rpi-sysroot
RPI_IMG_URL := https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2025-05-13/2025-05-13-raspios-bookworm-arm64-lite.img.xz
RPI_IMG_BASE_NAME := raspios-bookworm-arm64-lite
RPI_IMG_PATH := $(IMG_DIR)/$(RPI_IMG_BASE_NAME).img
LOSETUP_PATH_CMD := sudo losetup -a | grep $(RPI_IMG_PATH) | cut -f1 -d ':'

all: build/rpi-example

build out $(IMG_DIR) $(SYSROOT):
	mkdir -p $@

build/rpi-example: main.cpp Makefile | build
	aarch64-linux-gnu-g++ \
		--sysroot=$(SYSROOT) \
		-L $(SYSROOT)/usr/lib/ \
		-L $(SYSROOT)/usr/lib/aarch64-linux-gnu \
		-L $(SYSROOT)/usr/lib/gcc/aarch64-linux-gnu/12/ \
		-Wl,-rpath-link,$(SYSROOT)/usr/lib \
		-Wl,-rpath-link,$(SYSROOT)/usr/lib/aarch64-linux-gnu \
		-Wl,-rpath-link,$(SYSROOT)/usr/lib/gcc/aarch64-linux-gnu/12/ \
		$< -o $@

clean:
	rm -r build

$(RPI_IMG_PATH): | $(RPI_IMG_PATH)/.xz
	xz -d -k $|

$(RPI_IMG_PATH).xz: | $(IMG_DIR)
	curl $(RPI_IMG_URL) -o $@

losetup:
	LOSETUP_PATH=$$($(LOSETUP_PATH_CMD))
	if [ -z "$$LOSETUP_PATH" ]; then \
		echo "No existing loop device, creating..."; \
		sudo losetup -Pf $(RPI_IMG_PATH); \
	else \
		echo "Using existing loop device: $$LOSETUP_PATH"; \
	fi

$(SYSROOT)/usr:
	LOSETUP_PATH=$$($(LOSETUP_PATH_CMD))
	sudo mount $${LOSETUP_PATH}p2 $(SYSROOT)

mount:| losetup $(SYSROOT) $(SYSROOT)/usr
	sudo mount --bind /dev $(SYSROOT)/dev
	sudo mount --bind /sys $(SYSROOT)/sys
	sudo mount --bind /proc $(SYSROOT)/proc
	sudo mount --bind /dev/pts $(SYSROOT)/dev/pts
	sudo mount --bind /etc/resolv.conf $(SYSROOT)/etc/resolv.conf

umount:
	sudo umount -R $(SYSROOT)
	LOSETUP_PATH=$$($(LOSETUP_PATH_CMD))
	sudo losetup -d $${LOSETUP_PATH}

install:
	sudo pacman -S qemu-user-static-binfmt

chroot:
	sudo cp /usr/bin/qemu-arm-static $(SYSROOT)/usr/bin/
	sudo chroot $(SYSROOT) /usr/bin/bash

