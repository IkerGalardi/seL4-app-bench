#include <stdint.h>

#include <sddf/util/util.h>

/*
 * Brought to you by the musl developers:
 * https://github.com/kraj/musl/blob/ff441c9ddfefbb94e5881ddd5112b24a944dc36c/src/prng/rand.c
 */
int rand()
{
    static uint64_t seed = 158710598;
    seed = 6364136223846793005ULL * seed + 1;
	return seed >> 33;
}


int atoi(const char *s)
{
    return sddf_atoi(s);
}
