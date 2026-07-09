#pragma once

#include <mach-o/dyld.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <mach/mach.h>
#include <libkern/OSCacheControl.h>

typedef struct {
    uintptr_t fn_rva;
    uintptr_t entry_vm;
} IL2HookEntry;

static const IL2HookEntry il2_hook_table[] = {
    {0x1AFD2A8, 0x57A2138},  // AccountManager.CanPlayOnline()
    {0x1BBBE38, 0x57B0028},  // AmongUsClient.StartGame()
    {0x1BBBE60, 0x57B0030},  // AmongUsClient.Update()
    {0x1BBDBBC, 0x57B00B0},  // AmongUsClient.OnGameJoined()
    {0x1B4DA3C, 0x57AC2C8},  // BanMenu.SetVisible(bool)
    {0x1B55BFC, 0x57AC778},  // ChatController.SendChat()
    {0x1B3C564, 0x57AB8C8},  // GameStartManager.Update()
    {0x1EC5A30, 0x57AA930},  // GameData.GetPlayerById(int)
    {0x1B2E880, 0x57AAF38},  // GameManager.CanReportBodies()
    {0x1B2DD48, 0x57AAF80},  // GameManager.RpcEndGame(...)
    {0x1E61D54, 0x57A68E8},  // HatManager.get_AllSkins()
    {0x1E61D6C, 0x57A6900},  // HatManager.get_AllPets()
    {0x1E62754, 0x57A6948},  // HatManager.GetUnlockedPets()
    {0x1E62990, 0x57A6958},  // HatManager.GetUnlockedHats()
    {0x1B74334, 0x57AD748},  // HudManager.Update()
    {0x1DABFA8, 0x57BF820},  // InnerNetClient.get_AmHost()
    {0x1B75450, 0x57AE110},  // MeetingHud.ServerStart()
    {0x1B86170, 0x57AE0E8},  // MeetingHud.Update()
    {0x1B87238, 0x57AE118},  // MeetingHud.Close()
    {0x1B87384, 0x57AE120},  // MeetingHud.VotingComplete(...)
    {0x1B88C58, 0x57AE150},  // MeetingHud.CastVote(...)
    {0x1B89F3C, 0x57AE1F0},  // MeetingHud.Deserialize(...)
    {0x1C16E14, 0x57B2740},  // PingTracker.Update()
    {0x1C42BBC, 0x57B3458},  // PlayerControl.get_Data()
    {0x1C43320, 0x57B3410},  // PlayerControl.get_CanMove()
    {0x1C439E4, 0x57B3460},  // PlayerControl.SetKillTimer(float)
    {0x1C449E4, 0x57B34B8},  // PlayerControl.FixedUpdate()
    {0x1C47524, 0x57B3540},  // PlayerControl.Die(DeathReason, bool)
    {0x1C47D90, 0x57B3548},  // PlayerControl.Revive()
    {0x1C4C5C4, 0x57B3670},  // PlayerControl.MurderPlayer(...)
    {0x1C518F4, 0x57B37F8},  // PlayerControl.RpcCompleteTask(uint)
    {0x1C519C4, 0x57B3800},  // PlayerControl.RpcSetRole(RoleTypes)
    {0x1C52D5C, 0x57B38C8},  // PlayerControl.RpcSyncSettings(byte[])
    {0x1C59F34, 0x57B3DF8},  // PlayerPhysics.FixedUpdate()
    {0x1C5A1C4, 0x57B3E60},  // PlayerPhysics.HandleAnimation(bool)
    {0x1C5A74C, 0x57B3E10},  // PlayerPhysics.LateUpdate()
    {0x1C5B13C, 0x57B3EA0},  // PlayerPhysics.CoEnterVent(int)
    {0x1C5B1C4, 0x57B3EA8},  // PlayerPhysics.CoExitVent(int)
    {0x1E1BBE0, 0x57C3FE8},  // PlayerCustomizationData.set_Name(string)
    {0x1E1BCF8, 0x57C4008},  // PlayerCustomizationData.set_Pet(string)
    {0x1E1BD84, 0x57C4018},  // PlayerCustomizationData.set_Hat(string)
    {0x1E1BE10, 0x57C4028},  // PlayerCustomizationData.set_Skin(string)
    {0x1E1BE9C, 0x57C4038},  // PlayerCustomizationData.set_Visor(string)
    {0x1E1BF28, 0x57C4048},  // PlayerCustomizationData.set_NamePlate(string)
    {0x1C8E154, 0x57B5B38},  // RoleBehaviour.get_IsImpostor()
    {0x1C95AA8, 0x57B5CD0},  // RoleManager.SetRole(...)
    {0x1C97584, 0x57B5D10},  // RoleManager.IsImpostorRole(RoleTypes)
    {0x44A6874, 0x59FC440},  // SceneManager.Internal_SceneLoaded(...)
    {0x1CC9E54, 0x57B76A0},  // ShipStatus.UpdateSystem(...)
    {0x1CCAEA8, 0x57B76D8},  // ShipStatus.FixedUpdate()
    {0x1CCB1C8, 0x57B76E0},  // ShipStatus.CalculateLightRadius(...)
};

#define IL2_HOOK_COUNT (sizeof(il2_hook_table) / sizeof(il2_hook_table[0]))

// Check if a memory page has write permission.
static inline bool page_is_writable(uintptr_t addr) {
    vm_address_t region_addr = addr;
    vm_size_t region_size = 0;
    struct vm_region_submap_info_64 info;
    mach_msg_type_number_t count = VM_REGION_SUBMAP_INFO_COUNT_64;
    natural_t depth = 0;
    kern_return_t kr = vm_region_64(mach_task_self(), &region_addr, &region_size,
                                    VM_REGION_BASIC_INFO_64, (vm_region_info_t)&info,
                                    &count, &depth);
    return kr == KERN_SUCCESS && (info.protection & VM_PROT_WRITE) != 0;
}

// Install hook by writing replacement pointer into the __DATA dispatch table.
// Fallback when vm_protect code-patching fails (e.g., jailed A16).
// NOTE: The table stores RVAs (not absolute pointers), so *original
// must be base+fn_rva, NOT the table value.
static inline bool hook_via_entry_table(uintptr_t fn_rva, void *replacement,
                                        void **original) {
    uintptr_t base = get_unity_base();
    if (base == 0) return false;

    for (uint32_t i = 0; i < IL2_HOOK_COUNT; i++) {
        if (il2_hook_table[i].fn_rva == fn_rva) {
            uintptr_t entry_addr = base + il2_hook_table[i].entry_vm;

            // If page isn't already writable, try vm_protect(COPY) on __DATA_CONST
            if (!page_is_writable(entry_addr)) {
                vm_address_t page = entry_addr & ~(vm_address_t)0x3FFF;
                kern_return_t kr = vm_protect(mach_task_self(), page, 0x4000, FALSE,
                                              VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
                if (kr != KERN_SUCCESS) return false;
            }

            volatile uintptr_t *entry = (volatile uintptr_t *)entry_addr;
            if (original) *original = (void *)(base + fn_rva);
            *entry = (uintptr_t)replacement;

            return true;
        }
    }
    return false;
}

// ARM64 function-code patching via vm_protect.
static inline bool hook_via_protect(uintptr_t target, void *replacement,
                                    void **original) {
    vm_address_t page = target & ~(vm_address_t)0x3FFF;

    kern_return_t kr = vm_protect(mach_task_self(), page, 0x4000, FALSE,
                                  VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
    if (kr != KERN_SUCCESS) {
        kr = vm_protect(mach_task_self(), page, 0x4000, FALSE,
                        VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE);
        if (kr != KERN_SUCCESS) return false;
    }

    uint32_t saved[4];
    for (int i = 0; i < 4; i++)
        saved[i] = ((volatile uint32_t *)target)[i];

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
        sys_dcache_flush((void *)tramp, 32);
        sys_icache_invalidate((void *)tramp, 32);

        *original = (void *)tramp;
    }

    ((volatile uint32_t *)target)[0] = 0x58000051;  // ldr x17, #8
    ((volatile uint32_t *)target)[1] = 0xD61F0220;  // br x17
    *(volatile uintptr_t *)(target + 8) = (uintptr_t)replacement;

    sys_dcache_flush((void *)target, 16);
    sys_icache_invalidate((void *)target, 16);

    vm_protect(mach_task_self(), page, 0x4000, FALSE,
               VM_PROT_READ | VM_PROT_EXECUTE);

    return true;
}

// Try code-patching first; fall back to entry-table hook
// Uses get_real_offset() for correct ASLR-adjusted target address
// Reports results to g_hookSuccess / g_hookFailed for debugging
#define TRY_HOOK(offset, replace, origPtr) \
    do { \
        if ((offset) != 0x0) { \
            uintptr_t _target = get_real_offset(offset); \
            if (_target != 0 && hook_via_protect(_target, \
                                    (void *)(replace), (void **)(origPtr))) { \
                g_hookSuccess++; \
            } else if (hook_via_entry_table((offset), \
                                    (void *)(replace), (void **)(origPtr))) { \
                g_hookSuccess++; \
            } else { \
                g_hookFailed++; \
            } \
        } \
    } while (0)
