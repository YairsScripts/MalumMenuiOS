#pragma once

#include <mach-o/dyld.h>
#include <stdint.h>
#include <stdbool.h>

typedef struct {
    uintptr_t fn_rva;
    uintptr_t entry_vm;
} IL2HookEntry;

// ═══════════════════════════════════════════════════════════════════════════════
//  VERIFIED METHOD POINTER TABLE ENTRIES
//  Only entries with confirmed fn_rva AND entry_vm are listed here.
//  Each entry_writes the replacement pointer at base + entry_vm.
//  Adding wrong entry_vm WILL CORRUPT MEMORY → CRASH.
// ═══════════════════════════════════════════════════════════════════════════════

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

// Strip PAC bits (arm64e) – noop on plain arm64
static inline uintptr_t strip_pac(uintptr_t ptr) {
    return ptr & 0x0000FFFFFFFFFFFFull;
}

// Rough size of UnityFramework binary (sanity bound, ~95MB)
#define UNITY_BINARY_MAX_SIZE 0x6000000

// Install hook: write replacement at the method pointer table entry.
// fn_rva must match an entry in il2_hook_table.
// sanity: only writes if the existing pointer looks valid (within binary range).
static inline bool IL2Hook(uintptr_t fn_rva, void *replacement, void **original) {
    uintptr_t base = get_unity_base();
    if (base == 0) return false;

    for (uint32_t i = 0; i < IL2_HOOK_COUNT; i++) {
        if (il2_hook_table[i].fn_rva == fn_rva) {
            volatile uintptr_t *entry = (volatile uintptr_t *)(base + il2_hook_table[i].entry_vm);

            uintptr_t actual_addr = strip_pac(*entry);

            // Sanity: the existing pointer must point within UnityFramework
            // If it doesn't, the entry_vm is wrong or PAC strip failed – skip.
            if (actual_addr < base || actual_addr > base + UNITY_BINARY_MAX_SIZE) {
                return false;
            }

            if (original) *original = (void *)actual_addr;

            *entry = (uintptr_t)replacement;
            return true;
        }
    }
    return false;
}
