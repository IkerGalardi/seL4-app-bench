MICROKIT_PATH=../vendor/microkit-sdk
MICROKIT_BOARD=qemu_virt_aarch64
MICROKIT_CONFIG=release
MICROKIT_BOARD_DIR=$(MICROKIT_PATH)/board/$(MICROKIT_BOARD)/$(MICROKIT_CONFIG)
MICROKIT_TOOL=$(MICROKIT_PATH)/bin/microkit
TOOLCHAIN_CPU=cortex-a53
TOOLCHAIN_PREFIX=aarch64-linux-gnu
ARCH=aarch64
CC=$(TOOLCHAIN_PREFIX)-gcc
LD=$(TOOLCHAIN_PREFIX)-ld
AS=$(TOOLCHAIN_PREFIX)-gcc
OBJCOPY=$(TOOLCHAIN_PREFIX)-objcopy
SDDF=../vendor/sddf
RANLIB=ranlib
SDDF_CUSTOM_LIBC=1

SDDF_INCLUDE=-I../vendor/sddf/include \
             -I../vendor/sddf/include/microkit/ \
             -I../vendor/sddf/network/ipstacks/lwip/src/include \
             -Ilwip/include

CFLAGS=-nostdlib -ffreestanding -g -Wall -Wextra -mstrict-align \
       -I$(MICROKIT_BOARD_DIR)/include -DBOARD_$(MICROKIT_BOARD) \
       $(SDDF_INCLUDE) -Ivendor/sddf/network/ipstacks/lwip/src/include\
       -Wno-unused-function -Wno-unused-parameter -Ibuild/lwip/include \
       -Wno-sign-compare -Wno-implicit-function-declaration
LDFLAGS=-L$(MICROKIT_BOARD_DIR)/lib -L.

LIBS=--start-group -lmicrokit -Tmicrokit.ld -lsddf_util_debug --end-group

SDDF_BIN=serial_driver.elf \
         serial_virt_rx.elf \
         serial_virt_tx.elf \
         eth_driver_virtio.elf \
         network_copy.elf \
         network_virt_rx.elf \
         network_virt_tx.elf \
         timer_driver.elf

all: loader.img

MICROKIT_FLAGS =webserver.system
MICROKIT_FLAGS+=--search-path ./build
MICROKIT_FLAGS+=--board $(MICROKIT_BOARD)
MICROKIT_FLAGS+=--config $(MICROKIT_CONFIG)
MICROKIT_FLAGS+=-o $(IMG)
MICROKIT_FLAGS+=-r $(IMG_REPORT)
loader.img: $(SDDF_BIN) webserver.elf webserver.system
	$(MICROKIT_TOOL) $(MICROKIT_FLAGS)


include ../vendor/sddf/util/util.mk

include ../vendor/sddf/drivers/serial/arm/serial_driver.mk
include ../vendor/sddf/serial/components/serial_components.mk

include ../vendor/sddf/drivers/network/virtio/mmio/eth_driver.mk
include ../vendor/sddf/network/components/network_components.mk
include ../vendor/sddf/network/lib_sddf_lwip/lib_sddf_lwip.mk

include ../vendor/sddf/drivers/timer/arm/timer_driver.mk

WEBSERVER_OBJ=webserver/webserver.o \
              webserver/fs.o \
              webserver/httpd.o

servers:
	mkdir -p servers

webserver/%.o: ../servers/%.c
	$(CC) -c $(CFLAGS) $< -o $@

webserver/%.o: ../vendor/sddf/network/ipstacks/lwip/src/apps/http/%.c
	$(CC) -c $(CFLAGS) $< -o $@

webserver.elf: $(WEBSERVER_OBJ) libsddf_util_debug.a lib_sddf_lwip.a
	$(LD) $(WEBSERVER_OBJ) -o webserver.elf $(LDFLAGS) -l_sddf_lwip $(LIBS) $(LIBC_OBJ)
