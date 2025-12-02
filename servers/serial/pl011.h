#ifndef PL011_H
#define PL011_H

void pl011_initialize();

char pl011_interrupt();

void pl011_sendchar(char c);

void pl011_sendstr(char *c);

#endif // PL011_H
