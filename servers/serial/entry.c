#include <microkit.h>
#include "pl011.h"

#define NOTIFICATION_PL011_INTERRUPT 0

void init()
{
    pl011_initialize();

    pl011_sendstr("seriald: initialized\n");
}

void notified(microkit_channel channel)
{
    if (channel == NOTIFICATION_PL011_INTERRUPT) {
        pl011_interrupt();

        microkit_irq_ack(channel);
    }
}
