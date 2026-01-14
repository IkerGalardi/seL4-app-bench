################################################################################
# VARIABLE CONFIGURATION                                                       #
################################################################################

# Microkit SDK configuration
MICROKIT_PATH=vendor/microkit-sdk
MICROKIT_BOARD=qemu_virt_aarch64
MICROKIT_CONFIG=release
MICROKIT_BOARD_DIR=$(MICROKIT_PATH)/board/$(MICROKIT_BOARD)/$(MICROKIT_CONFIG)
MICROKIT_TOOL=$(MICROKIT_PATH)/bin/microkit

# Toolchain configuration
TOOLCHAIN_CPU=cortex-a53
TOOLCHAIN_PREFIX=aarch64-linux-gnu
CC=$(TOOLCHAIN_PREFIX)-gcc
LD=$(TOOLCHAIN_PREFIX)-ld
AS=$(TOOLCHAIN_PREFIX)-gcc
OBJCOPY=$(TOOLCHAIN_PREFIX)-objcopy
CFLAGS=-nostdlib -ffreestanding -g -Wall -Wextra -mstrict-align \
       -I$(MICROKIT_BOARD_DIR)/include -DBOARD_$(MICROKIT_BOARD) \
       -Ivendor/sddf/include -Ivendor/sddf/include/microkit/ \
       -Ivendor/sddf/network/ipstacks/lwip/src/include\
       -Wno-unused-function -Wno-unused-parameter -Ibuild/lwip/include \
       -Wno-sign-compare
LDFLAGS=-L$(MICROKIT_BOARD_DIR)/lib -lmicrokit -Tmicrokit.ld -Lbuild -lsddf

VIRTIO_DISCOVER=vendor/VirtioDiscover-Aarch64-Loader-Off0x70000000.img

# Resulting artifacts
IMG=build/loader.img
IMG_REPORT=build/report.txt

################################################################################
# IMAGE BUILDING                                                               #
################################################################################

SERIAL_PDS=build/serial_driver.elf \
           build/serial_virt_tx.elf \
           build/serial_virt_rx.elf

NET_PDS=build/eth_driver.elf \
        build/network_virt_rx.elf \
        build/network_virt_tx.elf \
        build/network_copy.elf

PDS=build/webserver.elf \
    $(SERIAL_PDS) \
    $(NET_PDS) \
    build/timer_driver.elf


all: $(IMG)

webserver.system: meta.py $(PDS)
	@echo "META"
	@ python3 meta.py
	@echo "OBJCOPY  --update-section .device_resources serial_driver.elf"
	@ $(OBJCOPY) --update-section .device_resources=build/serial_driver_device_resources.data build/serial_driver.elf
	@echo "OBJCOPY  --update-section .serial_driver_config serial_driver.elf"
	@ $(OBJCOPY) --update-section .serial_driver_config=build/serial_driver_config.data build/serial_driver.elf
	@echo "OBJCOPY  --update-section .serial_virt_tx_config serial_virt_tx.elf"
	@ $(OBJCOPY) --update-section .serial_virt_tx_config=build/serial_virt_tx.data build/serial_virt_tx.elf
	@echo "OBJCOPY  --update-section .serial_virt_rx_config serial_virt_rx.elf"
	@ $(OBJCOPY) --update-section .serial_virt_rx_config=build/serial_virt_rx.data build/serial_virt_rx.elf
	@echo "OBJCOPY  --update-section .serial_client_config webserver.elf"
	@ $(OBJCOPY) --update-section .serial_client_config=build/serial_client_webserver.data build/webserver.elf
	@echo "OBJCOPY  --update-section .net_client_config webserver.elf"
	@ $(OBJCOPY) --update-section .net_client_config=build/net_client_webserver.data build/webserver.elf
	@echo "OBJCOPY  --update-section .lib_sddf_lwip_config webserver.elf"
	@ $(OBJCOPY) --update-section .lib_sddf_lwip_config=build/lib_sddf_lwip_config_webserver.data build/webserver.elf
	@echo "OBJCOPY  --update-section .net_driver_config eth_driver.elf"
	@ $(OBJCOPY) --update-section .net_driver_config=build/net_driver.data build/eth_driver.elf
	@echo "OBJCOPY  --update-section .net_virt_tx_config network_virt_tx.elf"
	@ $(OBJCOPY) --update-section .net_virt_tx_config=build/net_virt_tx.data build/network_virt_tx.elf
	@echo "OBJCOPY  --update-section .net_virt_rx_config net_virt_rx.elf"
	@ $(OBJCOPY) --update-section .net_virt_rx_config=build/net_virt_rx.data build/network_virt_rx.elf
	@echo "OBJCOPY  --update-section .net_copy_config network_copy.elf"
	@ $(OBJCOPY) --update-section .net_copy_config=build/net_copy_network_copy.data build/network_copy.elf
	@echo "OBJCOPY  --update-section .device_resouces timer_driver.elf"
	@ $(OBJCOPY) --update-section .device_resources=build/timer_driver_device_resources.data build/timer_driver.elf
	@echo "OBJCOPY  --update-section .timer_client_config webserver.elf"
	@ $(OBJCOPY) --update-section .timer_client_config=build/timer_client_webserver.data build/webserver.elf

MICROKIT_FLAGS =webserver.system
MICROKIT_FLAGS+=--search-path ./build
MICROKIT_FLAGS+=--board $(MICROKIT_BOARD)
MICROKIT_FLAGS+=--config $(MICROKIT_CONFIG)
MICROKIT_FLAGS+=-o $(IMG)
MICROKIT_FLAGS+=-r $(IMG_REPORT)

$(IMG): $(PDS) webserver.system
	@echo "MICROKIT webserver.system"
	@ $(MICROKIT_TOOL) $(MICROKIT_FLAGS)


################################################################################
# Driver related stuff                                                         #
################################################################################

LIBSDDF_OBJ=build/libsddf/assert.o \
            build/libsddf/bitarray.o \
            build/libsddf/cache.o \
            build/libsddf/fsmalloc.o \
            build/libsddf/newlibc.o \
            build/libsddf/printf.o \
            build/libsddf/putchar_serial.o

build/libsddf.a: $(LIBSDDF_OBJ)
	@echo "AR       libsddf.a"
	@ $(AR) rcs build/libsddf.a $(LIBSDDF_OBJ)

build/libsddf/%.o: vendor/sddf/util/%.c
	@echo "CC       $<"
	@ $(CC) -c $(CFLAGS) $< -o $@

################################################################################
# LIBC                                                                         #
################################################################################
LIBC_OBJ=build/libc/string.o \
		 build/libc/stdlib.o

build/libc/%.o: libc/%.c
	@echo "CC       $<"
	@ $(CC) -c $(CFLAGS) $< -o $@

################################################################################
# WEBSERVER BUILDING                                                           #
################################################################################

WEBSERVER_OBJ=build/webserver/entry.o

build/webserver.elf: $(WEBSERVER_OBJ) $(LIBC_OBJ) build/libsddf.a build/liblwip.a
	@echo "LD       $@"
	@ $(LD) $(WEBSERVER_OBJ) -o build/webserver.elf $(LDFLAGS) -llwip $(LIBC_OBJ)

build/webserver/%.o: servers/webserver/%.c
	@echo "CC       $<"
	@ $(CC) -c $(CFLAGS) $< -o $@

################################################################################
# Serial related                                                               #
################################################################################

SERIAL_DRIVER_OBJ=build/serial_driver/uart.o
SERIAL_DRIVER_INCLUDE=-Ivendor/sddf/drivers/serial/arm/include

build/serial_driver.elf: $(SERIAL_DRIVER_OBJ) build/libsddf.a
	@echo "LD       $@"
	@ $(LD) $(SERIAL_DRIVER_OBJ) -o $@ $(LDFLAGS)

build/serial_driver/uart.o: vendor/sddf/drivers/serial/arm/uart.c
	@echo "CC       $<"
	@ $(CC) -c $(CFLAGS) $(SERIAL_DRIVER_INCLUDE) $< -o $@

build/serial_virt_tx.elf: build/serial_virt/virt_tx.o build/libsddf.a
	@echo "LD       $@"
	@ $(LD) build/serial_virt/virt_tx.o -o $@ $(LDFLAGS)

build/serial_virt_rx.elf: build/serial_virt/virt_rx.o build/libsddf.a
	@echo "LD       $@"
	@ $(LD) build/serial_virt/virt_rx.o -o $@ $(LDFLAGS)

build/serial_virt/virt_tx.o: vendor/sddf/serial/components/virt_tx.c
	@echo "CC       $<"
	@ $(CC) -c $(CFLAGS) $< -o $@

build/serial_virt/virt_rx.o: vendor/sddf/serial/components/virt_rx.c
	@echo "CC       $<"
	@ $(CC) -c $(CFLAGS) $< -o $@

################################################################################
# Network related                                                              #
################################################################################

LIBLWIP_OBJ=build/lwip/init.o \
            build/lwip/err.o \
            build/lwip/def.o \
            build/lwip/dns.o \
            build/lwip/inet_chksum.o \
            build/lwip/ip.o \
            build/lwip/mem.o \
            build/lwip/memp.o \
            build/lwip/netif.o \
            build/lwip/pbuf.o \
            build/lwip/raw.o \
            build/lwip/stats.o \
            build/lwip/sys.o \
            build/lwip/altcp.o \
            build/lwip/altcp_alloc.o \
            build/lwip/altcp_tcp.o \
            build/lwip/tcp.o \
            build/lwip/tcp_in.o \
            build/lwip/tcp_out.o \
            build/lwip/timeouts.o \
            build/lwip/udp.o \
            build/lwip/autoip.o \
            build/lwip/dhcp.o \
            build/lwip/etharp.o \
            build/lwip/icmp.o \
            build/lwip/igmp.o \
            build/lwip/ip4_frag.o \
            build/lwip/ip4.o \
            build/lwip/ip4_addr.o \
            build/lwip/ethernet.o \
            build/lwip/sddf_lwip.o

LIBLWIP_INCLUDE=-Ivendor/sddf/network/ipstacks/lwip/src/include/ \
                -Ibuild/lwip/include

build/eth_driver.elf: build/eth_driver/ethernet.o build/libsddf.a
	@echo "LD       $@"
	@ $(LD) build/eth_driver/ethernet.o -o $@ $(LDFLAGS)

build/network_virt_rx.elf: build/eth_components/network_virt_rx.o build/libsddf.a
	@echo "LD       $@"
	@ $(LD) build/eth_components/network_virt_rx.o -o $@ $(LDFLAGS)

build/network_virt_tx.elf: build/eth_components/network_virt_tx.o build/libsddf.a
	@echo "LD       $@"
	@ $(LD) build/eth_components/network_virt_tx.o -o $@ $(LDFLAGS)

build/network_copy.elf: build/eth_components/network_copy.o build/libsddf.a
	@echo "LD       $@"
	@ $(LD) build/eth_components/network_copy.o -o $@ $(LDFLAGS)

build/liblwip.a: $(LIBLWIP_OBJ)
	@echo "AR       liblwip.a"
	@ $(AR) rcs build/liblwip.a $(LIBSDDF_OBJ)

build/eth_driver/ethernet.o: vendor/sddf/drivers/network/virtio/ethernet.c
	@echo "CC       $<"
	@ $(CC) -c $(CFLAGS) $< -o $@

build/eth_components/network_virt_rx.o: vendor/sddf/network/components/virt_rx.c
	@echo "CC       $<"
	@ $(CC) -c $(CFLAGS) $< -o $@

build/eth_components/network_virt_tx.o: vendor/sddf/network/components/virt_tx.c
	@echo "CC       $<"
	@ $(CC) -c $(CFLAGS) $< -o $@

build/eth_components/network_copy.o: vendor/sddf/network/components/copy.c
	@echo "CC       $<"
	@ $(CC) -c $(CFLAGS) $< -o $@

build/lwip/%.o: vendor/sddf/network/ipstacks/lwip/src/core/%.c
	@echo "CC       $<"
	@ $(CC) -c $(CFLAGS) $(LIBLWIP_INCLUDE) $< -o $@

build/lwip/%.o: vendor/sddf/network/ipstacks/lwip/src/core/ipv4/%.c
	@echo "CC       $<"
	@ $(CC) -c $(CFLAGS) $(LIBLWIP_INCLUDE) $< -o $@

build/lwip/%.o: vendor/sddf/network/ipstacks/lwip/src/api/%.c
	@echo "CC       $<"
	@ $(CC) -c $(CFLAGS) $(LIBLWIP_INCLUDE) $< -o $@

build/lwip/%.o: vendor/sddf/network/ipstacks/lwip/src/netif/%.c
	@echo "CC       $<"
	@ $(CC) -c $(CFLAGS) $(LIBLWIP_INCLUDE) $< -o $@

build/lwip/sddf_lwip.o: vendor/sddf/network/lib_sddf_lwip/lib_sddf_lwip.c
	@echo "CC       $<"
	@ $(CC) -c $(CFLAGS) $(LIBLWIP_INCLUDE) $< -o $@


################################################################################
# Timer related                                                                #
################################################################################

build/timer/timer.o: vendor/sddf/drivers/timer/arm/timer.c
	@echo "CC       $<"
	@ $(CC) -c $(CFLAGS) $< -o $@

build/timer_driver.elf: build/timer/timer.o build/libsddf.a
	@echo "LD       $@"
	@ $(LD) $< -o $@ $(LDFLAGS)

################################################################################
# VM Related                                                                   #
################################################################################

QEMU_MACHINE=-machine virt,virtualization=on

QEMU_FLAGS =-cpu $(TOOLCHAIN_CPU)
QEMU_FLAGS+=-nographic
QEMU_FLAGS+=-serial mon:stdio
QEMU_FLAGS+=-m size=2G
QEMU_FLAGS+=-netdev user,id=mynet0
QEMU_FLAGS+=-device virtio-net-device,netdev=mynet0,mac=52:55:00:d1:55:01

QEMU_FLAGS_SEL4=-device loader,file=$(IMG),addr=0x70000000,cpu-num=0
QEMU_FLAGS_DISCOVER=-device loader,file=$(VIRTIO_DISCOVER),addr=0x70000000,cpu-num=0

qemuvirt.dtb:
	qemu-system-aarch64 $(QEMU_MACHINE),dumpdtb=qemuvirt.dtb $(QEMU_FLAGS)


qemu: $(IMG)
	qemu-system-aarch64 $(QEMU_MACHINE) $(QEMU_FLAGS) $(QEMU_FLAGS_SEL4)

virtio-discover: $(VIRTIO_DISCOVER)
	@ timeout -f --preserve-status 1s qemu-system-aarch64 $(QEMU_MACHINE) $(QEMU_FLAGS) $(QEMU_FLAGS_DISCOVER) 2> /dev/null

################################################################################
# BUILD ENVIRONMENT                                                            #
################################################################################

buildenv:
	docker build . -t sel4webserverdev

DOCKER_FLAGS =run --name sel4webserverdev --rm -v $(shell pwd):/code
DOCKER_FLAGS+=-w /code/ -it sel4webserverdev

env:
	docker $(DOCKER_FLAGS) 2> /dev/null || docker exec -it sel4webserverdev bash

################################################################################
# MISC                                                                         #
################################################################################

TO_REMOVE+=build/*.a
TO_REMOVE+=build/*.elf
TO_REMOVE+=build/*.data
TO_REMOVE+=build/eth_components/*.o
TO_REMOVE+=build/eth_driver/*.o
TO_REMOVE+=build/libsddf/*.o
TO_REMOVE+=build/lwip/*.o
TO_REMOVE+=build/serial_driver/*.o
TO_REMOVE+=build/webserver/*.o
TO_REMOVE+=build/loader.img
TO_REMOVE+=build/report.txt

clean:
	rm -f $(TO_REMOVE)

$(VIRTIO_DISCOVER):
	wget https://github.com/IkerGalardi/VirtioDiscover/releases/download/v0.1.0/VirtioDiscover-Aarch64-Loader-Off0x70000000.img -O $(VIRTIO_DISCOVER)
