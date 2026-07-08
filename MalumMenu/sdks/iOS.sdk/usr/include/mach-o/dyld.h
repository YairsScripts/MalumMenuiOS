#pragma once
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct mach_header_64 { uint32_t magic; } mach_header_64_t;
uint32_t _dyld_image_count(void);
const struct mach_header_64* _dyld_get_image_header(uint32_t index);
const char* _dyld_get_image_name(uint32_t index);
intptr_t _dyld_get_image_vmaddr_slide(uint32_t index);
#ifdef __cplusplus
}
#endif
