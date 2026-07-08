#pragma once

// ============================================================================
// Hooks.h – Internal hook helpers (MSHookFunction wrappers)
// ============================================================================

#include <substrate.h>
#include <mach-o/dyld.h>

// Convenience macro – install a MSHookFunction hook from an offset placeholder.
//  offset  : static uintptr_t placeholder (e.g. O_FixedUpdate)
//  replace : replacement function pointer
//  orig    : out-param for original trampoline
#define INSTALL_HOOK(offset, replace, orig) \
    do { \
        if ((offset) != 0x0) { \
            MSHookFunction((void *)real(offset), (void *)(replace), (void **)(orig)); \
        } \
    } while (0)

extern uintptr_t real(uintptr_t offset);
