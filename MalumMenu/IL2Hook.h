#pragma once

#include <mach-o/dyld.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <mach/mach.h>

// ── Old method-pointer-table approach removed ──
// The method pointer table at RVA 0x52A11B0 does NOT contain our target
// RVAs (0x1AFD2A8 etc).  Those entries live in a DIFFERENT table in
// __DATA_CONST that is NOT the Il2Cpp dispatch table.
//
// We now hook at the FUNCTION-CODE level (direct ARM64 patching), which
// intercepts EVERY call regardless of how it reaches the function.

// Install an ARM64 function hook by patching the first 16 bytes of the
// target function with a trampoline that jumps to `replacement`.
//
//   fn_rva   : RVA of the target function within UnityFramework
//   replace  : pointer to replacement function
//   original : out-param receives pointer to trampoline calling original
//
// Returns true on success, false on failure.
static inline bool HookFunction(uintptr_t fn_rva, void *replacement,
                                void **original) {
    uintptr_t base = get_unity_base();
    if (base == 0) return false;

    uintptr_t target = base + fn_rva;
    vm_address_t page = target & ~(vm_address_t)0x3FFF;

    // ── Make page writable via copy-on-write ──
    // VM_PROT_COPY forces a private copy, bypassing code-signing.
    kern_return_t kr = vm_protect(mach_task_self(), page, 0x4000, FALSE,
                                  VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
    if (kr != KERN_SUCCESS) {
        // Fallback: try direct RWX
        kr = vm_protect(mach_task_self(), page, 0x4000, FALSE,
                        VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE);
        if (kr != KERN_SUCCESS) return false;
    }

    // ── Save original instructions (16 bytes = 4 instructions) ──
    uint32_t saved[4];
    for (int i = 0; i < 4; i++)
        saved[i] = ((volatile uint32_t *)target)[i];

    // ── Build trampoline ──
    // Layout: saved[4] (16 B) + ldr x17, #8 (4 B) + br x17 (4 B) + addr (8 B)
    if (original) {
        vm_address_t tramp = 0;
        kr = vm_allocate(mach_task_self(), &tramp, 0x100, VM_FLAGS_ANYWHERE);
        if (kr != KERN_SUCCESS) return false;

        for (int i = 0; i < 4; i++)
            ((volatile uint32_t *)tramp)[i] = saved[i];

        ((volatile uint32_t *)(tramp + 16))[0] = 0x58000051;  // ldr x17, #8
        ((volatile uint32_t *)(tramp + 16))[1] = 0xD61F0220;  // br x17
        *(volatile uintptr_t *)(tramp + 24) = target + 16;

        vm_protect(mach_task_self(), tramp, 0x100, FALSE,
                   VM_PROT_READ | VM_PROT_EXECUTE);
        __builtin___clear_cache((char *)tramp, (char *)(tramp + 32));

        *original = (void *)tramp;
    }

    // ── Write hook: ldr x17, #8 ; br x17 ; <replacement addr> ──
    ((volatile uint32_t *)target)[0] = 0x58000051;  // ldr x17, #8
    ((volatile uint32_t *)target)[1] = 0xD61F0220;  // br x17
    *(volatile uintptr_t *)(target + 8) = (uintptr_t)replacement;

    __builtin___clear_cache((char *)target, (char *)(target + 16));

    // ── Restore protection to RX ──
    vm_protect(mach_task_self(), page, 0x4000, FALSE,
               VM_PROT_READ | VM_PROT_EXECUTE);

    return true;
}

#define HOOK_FUNC(offset, replace, origPtr) \
    HookFunction((offset), (void *)(replace), (void **)(origPtr))
