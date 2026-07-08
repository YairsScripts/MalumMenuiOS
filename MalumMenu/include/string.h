#ifndef _STRING_H
#define _STRING_H
#ifdef __cplusplus
extern "C" {
#endif
char *strstr(const char *s1, const char *s2);
void *memcpy(void *dest, const void *src, unsigned long n);
void *memset(void *s, int c, unsigned long n);
#ifdef __cplusplus
}
#endif
#endif
