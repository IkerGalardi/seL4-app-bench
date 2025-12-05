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
	   -I$(MICROKIT_BOARD_DIR)/include -DBOARD_$(MICROKIT_BOARD)
LDFLAGS=-L$(MICROKIT_BOARD_DIR)/lib -lmicrokit -Tmicrokit.ld

# Resulting artifacts
IMG=build/loader.img
IMG_REPORT=build/report.txt

################################################################################
# IMAGE BUILDING                                                               #
################################################################################

all: $(IMG)

$(IMG): build/seriald.elf webserver.system
	$(MICROKIT_TOOL) webserver.system \
            --search-path ./build \
            --board $(MICROKIT_BOARD) \
            --config $(MICROKIT_CONFIG) \
            -o $(IMG) \
            -r $(IMG_REPORT)

################################################################################
# SERIALD BUILDING                                                             #
################################################################################

SERIALD_OBJ=build/seriald/entry.o \
            build/seriald/pl011.o

build/seriald.elf: $(SERIALD_OBJ)
	$(LD) $(LDFLAGS) $(SERIALD_OBJ) -o build/seriald.elf

build/seriald/%.o: servers/serial/%.c
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
	rm -f build/seriald.elf build/seriald/*.o
