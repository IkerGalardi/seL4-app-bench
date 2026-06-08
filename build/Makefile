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
loader.img: $(SDDF_BIN) webserver.elf webserver.system
	$(MICROKIT_TOOL) $(MICROKIT_FLAGS) -o loader.img -r report.txt

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

webserver.system: ../meta.py qemuvirt.dtb
	python3 ../meta.py core_config/$(CONFIG_NUM_CORES).json
	$(OBJCOPY) --update-section .device_resources=serial_driver_device_resources.data serial_driver.elf
	$(OBJCOPY) --update-section .serial_driver_config=serial_driver_config.data serial_driver.elf
	$(OBJCOPY) --update-section .serial_virt_tx_config=serial_virt_tx.data serial_virt_tx.elf
	$(OBJCOPY) --update-section .serial_virt_rx_config=serial_virt_rx.data serial_virt_rx.elf
	$(OBJCOPY) --update-section .serial_client_config=serial_client_webserver.data webserver.elf
	$(OBJCOPY) --update-section .net_client_config=net_client_webserver.data webserver.elf
	$(OBJCOPY) --update-section .lib_sddf_lwip_config=lib_sddf_lwip_config_webserver.data webserver.elf
	$(OBJCOPY) --update-section .net_driver_config=net_driver.data eth_driver_virtio.elf
	$(OBJCOPY) --update-section .device_resources=eth_driver_device_resources.data eth_driver_virtio.elf
	$(OBJCOPY) --update-section .net_virt_tx_config=net_virt_tx.data network_virt_tx.elf
	$(OBJCOPY) --update-section .net_virt_rx_config=net_virt_rx.data network_virt_rx.elf
	$(OBJCOPY) --update-section .net_copy_config=net_copy_network_copy.data network_copy.elf
	$(OBJCOPY) --update-section .device_resources=timer_driver_device_resources.data timer_driver.elf
	$(OBJCOPY) --update-section .timer_client_config=timer_client_webserver.data webserver.elf
