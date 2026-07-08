#pragma once

// ============================================================================
// MalumMenu – iOS (ARM64) .dylib Tweak for Among Us (Unity IL2CPP)
// Floating overlaid menu controlled by a draggable touch icon.
// Inject via Sideloadly. Requires actual offsets from dump.cs.
// ============================================================================

#include <mach-o/dyld.h>
#include <stdint.h>
#include <stdbool.h>
#include <objc/runtime.h>
#include <string.h>

// ---------------------------------------------------------------------------
// ASLR Helper – finds UnityFramework base at runtime (iOS IL2CPP host dylib)
// Iterates loaded images and matches "UnityFramework" in the path.
// ---------------------------------------------------------------------------
static inline uintptr_t get_unity_base(void) {
    static uintptr_t base = 0;
    if (base != 0) return base;
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *name = _dyld_get_image_name(i);
        if (strstr(name, "UnityFramework")) {
            base = (uintptr_t)_dyld_get_image_header(i);
            return base;
        }
    }
    return 0;  // not loaded yet – safe, caller handles 0
}

static inline uintptr_t real(uintptr_t offset) {
    return get_unity_base() + offset;
}

// ============================================================================
//  OFFSETS – extracted from dump.cs (Il2CppDumper v6.7.46)
//  All values are RVAs within UnityFramework (__TEXT segment).
//  Runtime adjustment via real() above.
//  Build: Among Us iOS v2024.6.18 (Metadata v31)
// ============================================================================

// ── Game & Player Logic ─────────────────────────────────────────────────────
extern uintptr_t O_FixedUpdate;           // PlayerControl.FixedUpdate() – main per-frame hook
extern uintptr_t O_SetKillTimer;          // PlayerControl.SetKillTimer(float) – kill cooldown
extern uintptr_t O_MurderPlayer;          // PlayerControl.MurderPlayer(PlayerControl) – kill action
extern uintptr_t O_RpcCompleteTask;       // PlayerControl.RpcCompleteTask(uint) – task completion
extern uintptr_t O_get_IsImposter;        // PlayerControl.get_IsImposter() – impostor check
extern uintptr_t O_IsImposter;            // PlayerControl.IsImposter() – alt checker
extern uintptr_t O_get_Data;              // PlayerControl.get_Data() – player data struct
extern uintptr_t O_CanMove;               // PlayerControl.CanMove – movement lock check
extern uintptr_t O_Die;                   // PlayerControl.Die(DeathReason) – death handler
extern uintptr_t O_Revive;                // PlayerControl.Revive() – respawn

// ── Roles & Modifiers ───────────────────────────────────────────────────────
extern uintptr_t O_SetRole;               // RoleManager.SetRole(RoleTypes)
extern uintptr_t O_get_Role;              // RoleManager.get_Role()
extern uintptr_t O_IsRole;                // RoleManager.IsRole(RoleTypes)
extern uintptr_t O_CanReport;             // PlayerControl.CanReport – can-report checker
extern uintptr_t O_CanVent;               // PlayerControl.CanVent – can-vent checker

// ── Cosmetics & Unlocks ─────────────────────────────────────────────────────
extern uintptr_t O_get_HasUnlocked;       // UnlockManager.get_HasUnlocked()
extern uintptr_t O_GetPurchaseStatus;     // StoreManager.GetPurchaseStatus(string)
extern uintptr_t O_get_GoldHats;          // HatManager.get_GoldHats
extern uintptr_t O_get_Skins;             // SkinManager.get_Skins
extern uintptr_t O_get_Pets;              // PetManager.get_Pets

// ── Vision, Chat & Host ─────────────────────────────────────────────────────
extern uintptr_t O_CalculateLightRadius;  // PlayerControl.CalculateLightRadius(float)
extern uintptr_t O_get_Vision;            // PlayerControl.get_Vision – light modifier
extern uintptr_t O_HudUpdate;             // HudManager.Update() – HUD render cycle
extern uintptr_t O_SendChat;              // ChatController.SendChat(string)
extern uintptr_t O_get_AmHost;            // AmongUsClient.get_AmHost() – host check
extern uintptr_t O_RpcStartGame;          // AmongUsClient.RpcStartGame(GameData)
extern uintptr_t O_EndGame;               // GameManager.EndGame() / RpcEndGame
extern uintptr_t O_SyncSettings;          // PlayerControl.SyncSettings(OptionContainer)

// ============================================================================
//  FEATURE TOGGLE STATE  –  read/written by hooks & UI
// ============================================================================

typedef struct {
    // ── Player ──
    bool noKillCooldown;        // SetKillTimer → 0
    bool autoKill;              // FixedUpdate → murder nearest if target in range
    bool instantTasks;          // RpcCompleteTask → skip task progress
    bool wallhack;              // Override rendering / vision
    bool noClip;                // CanMove → true (walk through walls)
    bool godMode;               // Die → nop, Revive → trigger
    bool maxVision;             // CalculateLightRadius → float_max
    bool showGhosts;            // Allow seeing dead players

    // ── Roles ──
    bool forceImposter;         // get_IsImposter / IsImposter → true
    bool showRoles;             // HUD overlay role labels

    // ── Cosmetics ──
    bool unlockAll;             // get_HasUnlocked → true
    bool freePurchases;         // GetPurchaseStatus → true

    // ── Host ──
    bool alwaysHost;            // get_AmHost → true
    bool forceStart;            // RpcStartGame called every N frames
    bool forceEnd;              // EndGame called immediately

    // ── Chat ──
    bool bypassFilters;         // Strip / bypass chat filters
    bool spamChat;              // Resend chat message every N fixed-updates
} MenuToggles;

extern MenuToggles g_toggles;
extern bool        g_showMenu;       // UI visibility flag
extern bool        g_hooksReady;     // set after MSHookFunction calls succeed

// ============================================================================
//  HOOK REGISTRATION  –  call each once from constructor
// ============================================================================

#ifdef __cplusplus
extern "C" {
#endif

void hook_FixedUpdate(void);
void hook_SetKillTimer(void);
void hook_MurderPlayer(void);
void hook_RpcCompleteTask(void);
void hook_get_IsImposter(void);
void hook_IsImposter(void);
void hook_get_Data(void);
void hook_CanMove(void);
void hook_Die(void);
void hook_Revive(void);
void hook_SetRole(void);
void hook_get_Role(void);
void hook_IsRole(void);
void hook_CanReport(void);
void hook_CanVent(void);
void hook_get_HasUnlocked(void);
void hook_GetPurchaseStatus(void);
void hook_get_GoldHats(void);
void hook_get_Skins(void);
void hook_get_Pets(void);
void hook_CalculateLightRadius(void);
void hook_get_Vision(void);
void hook_HudUpdate(void);
void hook_SendChat(void);
void hook_get_AmHost(void);
void hook_RpcStartGame(void);
void hook_EndGame(void);
void hook_SyncSettings(void);

#ifdef __cplusplus
}
#endif
