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
       -Wno-unused-function -Wno-unused-parameter
LDFLAGS=-L$(MICROKIT_BOARD_DIR)/lib -lmicrokit -Tmicrokit.ld -Lbuild -lsddf

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
    $(NET_PDS)


all: $(IMG)

webserver.system: meta.py $(PDS)
	python3 meta.py
	$(OBJCOPY) --update-section .device_resources=build/serial_driver_device_resources.data build/serial_driver.elf
	$(OBJCOPY) --update-section .serial_driver_config=build/serial_driver_config.data build/serial_driver.elf
	$(OBJCOPY) --update-section .serial_virt_tx_config=build/serial_virt_tx.data build/serial_virt_tx.elf
	$(OBJCOPY) --update-section .serial_virt_rx_config=build/serial_virt_rx.data build/serial_virt_rx.elf
	$(OBJCOPY) --update-section .serial_client_config=build/serial_client_webserver.data build/webserver.elf

MICROKIT_FLAGS =webserver.system
MICROKIT_FLAGS+=--search-path ./build
MICROKIT_FLAGS+=--board $(MICROKIT_BOARD)
MICROKIT_FLAGS+=--config $(MICROKIT_CONFIG)
MICROKIT_FLAGS+=-o $(IMG)
MICROKIT_FLAGS+=-r $(IMG_REPORT)

$(IMG): $(PDS) webserver.system
	$(MICROKIT_TOOL) $(MICROKIT_FLAGS)


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
	$(AR) rcs build/libsddf.a $(LIBSDDF_OBJ)

build/libsddf/%.o: vendor/sddf/util/%.c
	$(CC) -c $(CFLAGS) $< -o $@

################################################################################
# WEBSERVER BUILDING                                                           #
################################################################################

WEBSERVER_OBJ=build/webserver/entry.o

build/webserver.elf: $(WEBSERVER_OBJ) build/libsddf.a
	$(LD) $(WEBSERVER_OBJ) -o build/webserver.elf $(LDFLAGS)

build/webserver/%.o: servers/webserver/%.c
	$(CC) -c $(CFLAGS) $< -o $@

################################################################################
# Serial related                                                               #
################################################################################

SERIAL_DRIVER_OBJ=build/serial_driver/uart.o
SERIAL_DRIVER_INCLUDE=-Ivendor/sddf/drivers/serial/arm/include

build/serial_driver.elf: $(SERIAL_DRIVER_OBJ) build/libsddf.a
	$(LD) $(SERIAL_DRIVER_OBJ) -o $@ $(LDFLAGS)

build/serial_driver/uart.o: vendor/sddf/drivers/serial/arm/uart.c
	$(CC) -c $(CFLAGS) $(SERIAL_DRIVER_INCLUDE) $< -o $@

build/serial_virt_tx.elf: build/serial_virt/virt_tx.o build/libsddf.a
	$(LD) build/serial_virt/virt_tx.o -o $@ $(LDFLAGS)

build/serial_virt_rx.elf: build/serial_virt/virt_rx.o build/libsddf.a
	$(LD) build/serial_virt/virt_rx.o -o $@ $(LDFLAGS)

build/serial_virt/virt_tx.o: vendor/sddf/serial/components/virt_tx.c
	$(CC) -c $(CFLAGS) $< -o $@

build/serial_virt/virt_rx.o: vendor/sddf/serial/components/virt_rx.c
	$(CC) -c $(CFLAGS) $< -o $@

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
            build/lwip/ethernet.o

LIBLWIP_INCLUDE=-Ivendor/sddf/network/ipstacks/lwip/src/include/ \
                -Ibuild/lwip/include

build/eth_driver.elf: build/eth_driver/ethernet.o build/libsddf.a
	$(LD) build/eth_driver/ethernet.o -o $@ $(LDFLAGS)

build/network_virt_rx.elf: build/eth_components/network_virt_rx.o build/libsddf.a
	$(LD) build/eth_components/network_virt_rx.o -o $@ $(LDFLAGS)

build/network_virt_tx.elf: build/eth_components/network_virt_tx.o build/libsddf.a
	$(LD) build/eth_components/network_virt_tx.o -o $@ $(LDFLAGS)

build/network_copy.elf: build/eth_components/network_copy.o build/libsddf.a
	$(LD) build/eth_components/network_virt_tx.o -o $@ $(LDFLAGS)

build/liblwip.a: $(LIBLWIP_OBJ)
	$(AR) rcs build/liblwip.a $(LIBSDDF_OBJ)

build/eth_driver/ethernet.o: vendor/sddf/drivers/network/virtio/ethernet.c
	$(CC) -c $(CFLAGS) $< -o $@

build/eth_components/network_virt_rx.o: vendor/sddf/network/components/virt_rx.c
	$(CC) -c $(CFLAGS) $< -o $@

build/eth_components/network_virt_tx.o: vendor/sddf/network/components/virt_tx.c
	$(CC) -c $(CFLAGS) $< -o $@

build/eth_components/network_copy.o: vendor/sddf/network/components/copy.c
	$(CC) -c $(CFLAGS) $< -o $@

build/lwip/%.o: vendor/sddf/network/ipstacks/lwip/src/core/%.c
	$(CC) -c $(CFLAGS) $(LIBLWIP_INCLUDE) $< -o $@

build/lwip/%.o: vendor/sddf/network/ipstacks/lwip/src/core/ipv4/%.c
	$(CC) -c $(CFLAGS) $(LIBLWIP_INCLUDE) $< -o $@

build/lwip/%.o: vendor/sddf/network/ipstacks/lwip/src/api/%.c
	$(CC) -c $(CFLAGS) $(LIBLWIP_INCLUDE) $< -o $@

build/lwip/%.o: vendor/sddf/network/ipstacks/lwip/src/netif/%.c
	$(CC) -c $(CFLAGS) $(LIBLWIP_INCLUDE) $< -o $@

################################################################################
# VM Related                                                                   #
################################################################################

QEMU_MACHINE=-machine virt,virtualization=on

QEMU_FLAGS =-cpu $(TOOLCHAIN_CPU)
QEMU_FLAGS+=-nographic
QEMU_FLAGS+=-serial mon:stdio
QEMU_FLAGS+=-device loader,file=$(IMG),addr=0x70000000,cpu-num=0
QEMU_FLAGS+=-m size=2G
QEMU_FLAGS+=-netdev user,id=mynet0
QEMU_FLAGS+=-device virtio-net-device,netdev=mynet0,mac=52:55:00:d1:55:01

qemuvirt.dtb:
	qemu-system-aarch64 $(QEMU_MACHINE),dumpdtb=qemuvirt.dtb $(QEMU_FLAGS)


qemu: $(IMG)
	qemu-system-aarch64 $(QEMU_MACHINE) $(QEMU_FLAGS)

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
