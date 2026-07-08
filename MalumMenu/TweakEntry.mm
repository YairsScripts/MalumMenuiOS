// ============================================================================
// TweakEntry.mm – .dylib constructor called when the library is injected.
// 1. Set your dump.cs offsets in a separate offsets.c file (linked at build).
// 2. Recompile and inject via Sideloadly.
// ============================================================================

#import "MalumMenu.h"
#import "FloatingOverlay.h"
#include <dispatch/dispatch.h>

extern "C" unsigned int sleep(unsigned int);

// ─── Global state definitions ───────────────────────────────────────────────
MenuToggles g_toggles    = {0};     // all features start OFF
bool         g_showMenu  = false;
bool         g_hooksReady = false;

// ─── Offset definitions – extracted from decrypted iOS IPA dump.cs
// All values are RVAs within UnityFramework (see ASLR helper).
// Verified against Among Us iOS v2024.6.18 (Metadata v31)
// ============================================================================

// Game & Player Logic (PlayerControl)
uintptr_t O_FixedUpdate           = 0x1C449E4;   // PlayerControl.FixedUpdate()
uintptr_t O_SetKillTimer           = 0x1C439E4;   // PlayerControl.SetKillTimer(float)
uintptr_t O_MurderPlayer           = 0x1C4C5C4;   // PlayerControl.MurderPlayer(PlayerControl, MurderResultFlags)
uintptr_t O_RpcCompleteTask        = 0x1C518F4;   // PlayerControl.RpcCompleteTask(uint idx)
uintptr_t O_get_IsImposter         = 0x1C8E154;   // RoleBehaviour.get_IsImpostor()  (not PlayerControl)
uintptr_t O_IsImposter             = 0x1C97584;   // RoleManager.IsImpostorRole(RoleTypes) static
uintptr_t O_get_Data               = 0x1C42BBC;   // PlayerControl.get_Data() → NetworkedPlayerInfo
uintptr_t O_CanMove                = 0x1C43320;   // PlayerControl.get_CanMove()
uintptr_t O_Die                    = 0x1C47524;   // PlayerControl.Die(DeathReason, bool assignGhostRole)
uintptr_t O_Revive                 = 0x1C47D90;   // PlayerControl.Revive()

// Roles & Modifiers
uintptr_t O_SetRole                = 0x1C95AA8;   // RoleManager.SetRole(PlayerControl, RoleTypes)
uintptr_t O_get_Role               = 0x0;         // Role is a field (RoleBehaviour*, offset 0x68 in NetworkedPlayerInfo)
uintptr_t O_IsRole                 = 0x0;         // Not found – use RoleType field (offset 0x50) or RoleManager.IsImpostorRole
uintptr_t O_CanReport              = 0x1B2E880;   // GameManager.CanReportBodies() virtual
uintptr_t O_CanVent                = 0x0;         // CanVent is a bool field at 0x63 in RoleBehaviour

// Cosmetics & Unlocks
uintptr_t O_get_HasUnlocked        = 0x1E62754;   // HatManager.GetUnlockedPets()  → returns all if empty
uintptr_t O_GetPurchaseStatus      = 0x0;         // Use InventoryManager / HatManager.GetUnlocked*
uintptr_t O_get_GoldHats           = 0x1E62990;   // HatManager.GetUnlockedHats()
uintptr_t O_get_Skins              = 0x1E61D54;   // HatManager.get_AllSkins()
uintptr_t O_get_Pets               = 0x1E61D6C;   // HatManager.get_AllPets()

// Vision, Chat & Host
uintptr_t O_CalculateLightRadius   = 0x1CCB1C8;   // ShipStatus.CalculateLightRadius(NetworkedPlayerInfo) virtual
uintptr_t O_get_Vision             = 0x0;         // Not found – modify ShipStatus.MaxLightRadius field (offset 0x48)
uintptr_t O_HudUpdate              = 0x1B74334;   // HudManager.Update()
uintptr_t O_SendChat               = 0x1B55BFC;   // ChatController.SendChat()
uintptr_t O_get_AmHost             = 0x1DABFA8;   // InnerNetClient.get_AmHost()
uintptr_t O_RpcStartGame           = 0x1BBBE38;   // AmongUsClient.StartGame()
uintptr_t O_EndGame                = 0x1B2DD48;   // GameManager.RpcEndGame(GameOverReason, bool)
uintptr_t O_SyncSettings           = 0x1C52D5C;   // PlayerControl.RpcSyncSettings(byte[])

// ─── Hook registration table ────────────────────────────────────────────────
static void register_all_hooks(void) {
    // Player Logic
    hook_FixedUpdate();
    hook_SetKillTimer();
    hook_MurderPlayer();
    hook_RpcCompleteTask();
    hook_get_IsImposter();
    hook_IsImposter();
    hook_get_Data();
    hook_CanMove();
    hook_Die();
    hook_Revive();

    // Roles
    hook_SetRole();
    hook_get_Role();
    hook_IsRole();
    hook_CanReport();
    hook_CanVent();

    // Cosmetics
    hook_get_HasUnlocked();
    hook_GetPurchaseStatus();
    hook_get_GoldHats();
    hook_get_Skins();
    hook_get_Pets();

    // Vision, Chat, Host
    hook_CalculateLightRadius();
    hook_get_Vision();
    hook_HudUpdate();
    hook_SendChat();
    hook_get_AmHost();
    hook_RpcStartGame();
    hook_EndGame();
    hook_SyncSettings();

    g_hooksReady = true;
}

// ─── Delayed init ──────────────────────────────────────────────────────────
// Waits for UnityFramework to load PLUS an extra 10s for Unity to finish
// initializing (splash, rendering setup, etc.) before installing hooks or UI.
static void delayed_init(void) {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        // Wait up to 60s for UnityFramework to appear
        for (int i = 0; i < 30; i++) {
            if (get_unity_base() != 0) break;
            sleep(2);
        }
        if (get_unity_base() == 0) return;  // never loaded, give up
        // Extra 10s for Unity to finish its init
        sleep(10);
        // Install hooks on background thread (safe: IL2CPP table writes)
        register_all_hooks();
        // Show UI on main thread (creates UIKit objects safely)
        [FloatingOverlay performSelectorOnMainThread:@selector(present)
                                         withObject:nil
                                      waitUntilDone:NO];
    });
}

// ─── Constructor – runs when dylib is loaded ────────────────────────────────
__attribute__((constructor))
static void initialize() {
    retry_hooks();
}
