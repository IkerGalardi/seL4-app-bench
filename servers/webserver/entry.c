#include <stdbool.h>
#include <stdint.h>
#include <os/sddf.h>
#include <sddf/util/util.h>
#include <sddf/util/string.h>
#include <sddf/util/printf.h>
#include <sddf/serial/queue.h>
#include <sddf/serial/config.h>

__attribute__((__section__(".serial_client_config"))) serial_client_config_t serial_config;


void init()
{
    microkit_dbg_puts("WEBSERVER: initialized\n");
}

void notified(microkit_channel channel)
{
}
