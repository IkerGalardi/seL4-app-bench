#include <stdbool.h>
#include <stdint.h>
#include <os/sddf.h>
#include <sddf/util/util.h>
#include <sddf/util/string.h>
#include <sddf/util/printf.h>
#include <sddf/serial/queue.h>
#include <sddf/serial/config.h>
#include <sddf/network/queue.h>
#include <sddf/network/config.h>
#include <sddf/network/lib_sddf_lwip.h>
#include <sddf/timer/client.h>
#include <sddf/timer/config.h>

__attribute__((__section__(".serial_client_config")))
serial_client_config_t serial_config;

__attribute__((__section__(".net_client_config")))
net_client_config_t net_config;

__attribute__((__section__(".lib_sddf_lwip_config")))
lib_sddf_lwip_config_t lwip_config;

__attribute__((__section__(".timer_client_config")))
timer_client_config_t timer_config;

serial_queue_handle_t serial_tx_queue_handle;

void init()
{
    assert(serial_config_check_magic(&serial_config));

    serial_queue_init(&serial_tx_queue_handle,
                      serial_config.tx.queue.vaddr,
                      serial_config.tx.data.size,
                      serial_config.tx.data.vaddr);
    serial_putchar_init(serial_config.tx.id, &serial_tx_queue_handle);

    sddf_printf("WEBSERVER: initialized\n");
}

void notified(microkit_channel channel)
{
}
