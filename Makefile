################################################################################
# VARIABLE CONFIGURATION                                                       #
################################################################################

# Microkit SDK configuration
MICROKIT_PATH=vendor/microkit-sdk
MICROKIT_BOARD=qemu_virt_aarch64
MICROKIT_CONFIG=debug
MICROKIT_BOARD_DIR=$(MICROKIT_PATH)/board/$(MICROKIT_BOARD)/$(MICROKIT_CONFIG)
MICROKIT_TOOL=$(MICROKIT_PATH)/bin/microkit

# Toolchain configuration
TOOLCHAIN_CPU=cortex-a53
TOOLCHAIN_PREFIX=aarch64-linux-gnu
CC=$(TOOLCHAIN_PREFIX)-gcc
LD=$(TOOLCHAIN_PREFIX)-ld
AS=$(TOOLCHAIN_PREFIX)-gcc
CFLAGS=-nostdlib -ffreestanding -g -Wall -Wextra \
       -I$(MICROKIT_BOARD_DIR)/include -DBOARD_$(MICROKIT_BOARD) \
       -Ivendor/sddf/include -Ivendor/sddf/include/microkit/
LDFLAGS=-L$(MICROKIT_BOARD_DIR)/lib -lmicrokit -Tmicrokit.ld -Lbuild -lsddf

# Resulting artifacts
IMG=build/loader.img
IMG_REPORT=build/report.txt

################################################################################
# IMAGE BUILDING                                                               #
################################################################################

DRIVER_PDS=build/serial_driver.elf \
           build/serial_virt_tx.elf \
           build/serial_virt_rx.elf

PDS=build/webserver.elf \
    $(DRIVER_PDS)


all: $(IMG)

webserver.system: meta.py build/serial_driver.elf
	python3 meta.py

$(IMG): $(PDS) webserver.system
	$(MICROKIT_TOOL) webserver.system \
            --search-path ./build \
            --board $(MICROKIT_BOARD) \
            --config $(MICROKIT_CONFIG) \
            -o $(IMG) \
            -r $(IMG_REPORT)


################################################################################
# Driver related stuff                                                         #
################################################################################

LIBSDDF_OBJ=build/libsddf/assert.o \
            build/libsddf/bitarray.o \
            build/libsddf/cache.o \
            build/libsddf/fsmalloc.o \
            build/libsddf/newlibc.o \
            build/libsddf/printf.o \
            build/libsddf/putchar_debug.o

build/libsddf.a: $(LIBSDDF_OBJ)
	$(AR) rcs build/libsddf.a $(LIBSDDF_OBJ)

build/libsddf/%.o: vendor/sddf/util/%.c
	$(CC) -c $(CFLAGS) $< -o $@

################################################################################
# WEBSERVER BUILDING                                                           #
################################################################################

WEBSERVER_OBJ=build/webserver/entry.o

build/webserver.elf: $(WEBSERVER_OBJ)
	$(LD) $(LDFLAGS) $(WEBSERVER_OBJ) -o build/webserver.elf

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
# VM Related                                                                   #
################################################################################

QEMU_FLAGS=-cpu $(TOOLCHAIN_CPU) \
           -nographic \
           -serial mon:stdio \
           -device loader,file=$(IMG),addr=0x70000000,cpu-num=0 \
           -m size=2G \
           -netdev user,id=mynet0 \
           -device virtio-net-device,netdev=mynet0,mac=52:55:00:d1:55:01

qemuvirt.dtb:
	qemu-system-aarch64 -machine virt,virtualization=on,dumpdtb=qemuvirt.dtb \
            $(QEMU_FLAGS)


qemu: $(IMG)
	qemu-system-aarch64 -machine virt,virtualization=on \
            $(QEMU_FLAGS)

################################################################################
# BUILD ENVIRONMENT                                                            #
################################################################################

buildenv:
	docker build . -t sel4webserverdev

env:
	docker run --name sel4webserverdev         \
	       --rm                                \
		   -v $(shell pwd):/code               \
		   -w /code/                           \
		   -it sel4webserverdev                \
			2> /dev/null ||                    \
		   docker exec -it sel4webserverdev sh

################################################################################
# MISC                                                                         #
################################################################################

clean:
	rm -f build/libsddf.a $(LIBSDDF_OBJ) \
      build/serial_driver.elf $(SERIAL_DRIVER_OBJ) \
      build/serial_virt_tx.elf build/serial_virt/*.o \
      build/webserver.elf $(WEBSERVER_OBJ)
