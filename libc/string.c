#include <sddf/util/string.h>

size_t strlen(const char *s)
{
    return sddf_strlen(s);
}

void *memcpy(void *dest, const void *src, size_t n)
{
    return sddf_memcpy(dest, src, n);
}

void *memset(void *s, int c, size_t n)
{
    return sddf_memset(s, c, n);
}

int strncmp(const char *a, const char *b, size_t n)
{
    return sddf_strncmp(a, b, n);
}

void *memmove(void *dest, const void *src, size_t n)
{
    return sddf_memmove(dest, src, n);
}

int memcmp(const void *a, const void *b, size_t n)
{
    return sddf_memcmp(a, b, n);
}
