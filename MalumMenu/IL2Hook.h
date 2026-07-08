#pragma once

// ============================================================================
// IL2Hook.h – Jail-free IL2CPP method hooking (patches method pointer table)
//
// Replaces MSHookFunction (code-page patching, needs jailbreak) with direct
// IL2CPP method pointer table patching in __DATA.__data (writable memory).
//
// The method pointer table is a dense array of function pointers in __DATA.
// Each entry corresponds to a C# method in the IL2CPP output. By replacing
// an entry, every call to that managed method goes through our function.
//
// No external libraries required – works on jailed iOS.
// ============================================================================

#include <mach-o/dyld.h>
#include <stdint.h>
#include <stdbool.h>

// ─── ASLR Helper – provided by MalumMenu.h ──────────────────────────────────
// Uses get_unity_base() from MalumMenu.h

// ─── Method Pointer Table Entry ─────────────────────────────────────────────
// Pre-computed __DATA.__data entry VM addresses for each target function.
// Extracted from Among Us iOS v2026.17.4 UnityFramework arm64 binary.
typedef struct {
    uintptr_t fn_rva;    // target function RVA (e.g., O_FixedUpdate)
    uintptr_t entry_vm;  // VM address of the 8-byte pointer in __DATA.__data
} IL2HookEntry;

static const IL2HookEntry il2_hook_table[] = {
    // ── Player & Game Logic ──
    {0x1C449E4, 0x57b34b8},   // PlayerControl.FixedUpdate()
    {0x1C439E4, 0x57b3460},   // PlayerControl.SetKillTimer(float)
    {0x1C4C5C4, 0x57b3670},   // PlayerControl.MurderPlayer(...)
    {0x1C518F4, 0x57b37f8},   // PlayerControl.RpcCompleteTask(uint)
    {0x1C8E154, 0x57b5b38},   // RoleBehaviour.get_IsImpostor()
    {0x1C97584, 0x57b5d10},   // RoleManager.IsImpostorRole(RoleTypes)
    {0x1C42BBC, 0x57b3458},   // PlayerControl.get_Data()
    {0x1C43320, 0x57b3410},   // PlayerControl.get_CanMove()
    {0x1C47524, 0x57b3540},   // PlayerControl.Die(DeathReason, bool)
    {0x1C47D90, 0x57b3548},   // PlayerControl.Revive()

    // ── Roles ──
    {0x1C95AA8, 0x57b5cd0},   // RoleManager.SetRole(PlayerControl, RoleTypes)
    {0x1B2E880, 0x57aaf38},   // GameManager.CanReportBodies()

    // ── Cosmetics & Unlocks ──
    {0x1E62754, 0x57a6948},   // HatManager.GetUnlockedPets()
    {0x1E62990, 0x57a6958},   // HatManager.GetUnlockedHats()
    {0x1E61D54, 0x57a68e8},   // HatManager.get_AllSkins()
    {0x1E61D6C, 0x57a6900},   // HatManager.get_AllPets()

    // ── Vision ──
    {0x1CCB1C8, 0x57b76e0},   // ShipStatus.CalculateLightRadius(...)

    // ── Chat & HUD ──
    {0x1B74334, 0x57ad748},   // HudManager.Update()
    {0x1B55BFC, 0x57ac778},   // ChatController.SendChat()

    // ── Host ──
    {0x1DABFA8, 0x57bf820},   // AmongUsClient.get_AmHost()
    {0x1BBBE38, 0x57b0028},   // AmongUsClient.RpcStartGame()
    {0x1B2DD48, 0x57aaf80},   // GameManager.RpcEndGame(...)
    {0x1C52D5C, 0x57b38c8},   // PlayerControl.RpcSyncSettings(byte[])
};

#define IL2_HOOK_COUNT (sizeof(il2_hook_table) / sizeof(il2_hook_table[0]))

// ─── Main Hook Function ─────────────────────────────────────────────────────
// Replaces a method's function pointer in the IL2CPP method pointer table.
//
//   fn_rva       – RVA of the target function (e.g., O_FixedUpdate = 0x1C449E4)
//   replacement  – pointer to the replacement function
//   original     – output: receives the original function pointer
//
// Returns true on success, false if not found in lookup table.
//
// Thread-safe: the write is a single atomic 8-byte store on ARM64.
// All hooks must be installed before any game code runs (from constructor).
// Strip PAC (Pointer Authentication Code) from arm64e pointers.
// On A16+/iOS 26, function pointers in memory have PAC in upper bits.
static inline uintptr_t strip_pac(uintptr_t ptr) {
    // Apple arm64e PAC uses bits [54:47] or similar; mask to 48-bit address.
    // The exact mask depends on ARM64E_HASHED_PAC: assume 48-bit VA space.
    return ptr & 0x0000FFFFFFFFFFFFull;
}

static inline bool IL2Hook(uintptr_t fn_rva, void *replacement, void **original) {
    uintptr_t base = get_unity_base();
    if (base == 0) return false;

    for (uint32_t i = 0; i < IL2_HOOK_COUNT; i++) {
        if (il2_hook_table[i].fn_rva == fn_rva) {
            volatile uintptr_t *entry = (volatile uintptr_t *)(base + il2_hook_table[i].entry_vm);

            uintptr_t expected = base + fn_rva;
            uintptr_t actual_addr = strip_pac(*entry);

            if (actual_addr != expected) {
                return false;
            }

            if (original) *original = (void *)actual_addr;
            // Write raw address (no PAC needed - our replacement is not PAC-signed,
            // which is fine because we're replacing a C++ vtable-style pointer)
            *entry = (uintptr_t)replacement;
            return true;
        }
    }
    return false;
}
