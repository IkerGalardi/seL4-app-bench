#include "pl011.h"
#include <stdint.h>

uintptr_t pl011_base_vaddr;

#define RHR_MASK 0b111111111
#define UARTDR 0x000
#define UARTFR 0x018
#define UARTIMSC 0x038
#define UARTICR 0x044
#define PL011_UARTFR_TXFF (1 << 5)
#define PL011_UARTFR_RXFE (1 << 4)

#define REG_PTR(base, offset) ((volatile uint32_t *)((base) + (offset)))

void pl011_initialize()
{
    *REG_PTR(pl011_base_vaddr, UARTIMSC) = 0x50;
}

char pl011_interrupt()
{
    *REG_PTR(pl011_base_vaddr, UARTICR) = 0x7f0;

    int ch = 0;

    if ((*REG_PTR(pl011_base_vaddr, UARTFR) & PL011_UARTFR_RXFE) == 0) {
        ch = *REG_PTR(pl011_base_vaddr, UARTDR) & RHR_MASK;
    }

    /*
     * Convert Newline to Carriage return; backspace to DEL
     */
    switch (ch) {
    case '\n':
        ch = '\r';
        break;
    case 8:
        ch = 0x7f;
        break;
    }
    return ch;
}


void pl011_sendchar(char c)
{
    while ((*REG_PTR(pl011_base_vaddr, UARTFR) & PL011_UARTFR_TXFF) != 0);

    *REG_PTR(pl011_base_vaddr, UARTDR) = c;
    if (c == '\r') {
        pl011_sendchar('\n');
    }
}

void pl011_sendstr(char *c)
{
    while (*c != '\0') {
        pl011_sendchar(*c);
        c++;
    }
}
