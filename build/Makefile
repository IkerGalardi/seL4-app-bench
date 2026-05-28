MICROKIT_PATH=../vendor/microkit-sdk
MICROKIT_BOARD=qemu_virt_aarch64
MICROKIT_CONFIG=release
MICROKIT_BOARD_DIR=$(MICROKIT_PATH)/board/$(MICROKIT_BOARD)/$(MICROKIT_CONFIG)
MICROKIT_TOOL=$(MICROKIT_PATH)/bin/microkit
ARCH=aarch64
SDDF=../vendor/sddf
RANLIB=ranlib
SDDF_CUSTOM_LIBC=1

SDDF_INCLUDE=-I../vendor/sddf/include \
             -I../vendor/sddf/include/microkit/

CFLAGS=-nostdlib -ffreestanding -g -Wall -Wextra -mstrict-align \
       -I$(MICROKIT_BOARD_DIR)/include -DBOARD_$(MICROKIT_BOARD) \
       $(SDDF_INCLUDE) -Ivendor/sddf/network/ipstacks/lwip/src/include\
       -Wno-unused-function -Wno-unused-parameter -Ibuild/lwip/include \
       -Wno-sign-compare
LDFLAGS=-L$(MICROKIT_BOARD_DIR)/lib -L.

LIBS=--start-group -lmicrokit -Tmicrokit.ld -lsddf_util_debug --end-group

SDDF_BIN=serial_driver.elf \
         serial_virt_rx.elf \
         serial_virt_tx.elf \
         eth_driver_virtio.elf \
         network_copy.elf \
         network_virt_rx.elf \
         network_virt_tx.elf

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
