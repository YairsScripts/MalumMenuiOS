// ============================================================================
// Hooks.mm – All IL2CPP method hooks for MalumMenu features.
// Each hook_<Name>() reads the global MenuToggles and modifies behaviour.
// Adjust the IL2CPP calling-convention signatures below if the iOS binary
// uses the extra "MethodInfo *" parameter (typical of modern Unity).
// ============================================================================

#import "MalumMenu.h"
#include "IL2Hook.h"

// ─────────────────────────────────────────────────────────────────────────────
//  ORIGINAL-FUNCTION POINTERS
// ─────────────────────────────────────────────────────────────────────────────

// Game & Player Logic (PlayerControl)
static void (*orig_FixedUpdate)(void *__this);
static void (*orig_SetKillTimer)(void *__this, float cooldown);
static void (*orig_MurderPlayer)(void *__this, void *target, int32_t resultFlags);
static void (*orig_RpcCompleteTask)(void *__this, uint32_t taskId);
static bool (*orig_get_IsImposter)(void *__this);          // RoleBehaviour.get_IsImpostor
static bool (*orig_IsImposter)(void *__this);              // RoleManager.IsImpostorRole (static)
static void *(*orig_get_Data)(void *__this);               // -> NetworkedPlayerInfo
static bool (*orig_CanMove)(void *__this);
static void (*orig_Die)(void *__this, int32_t reason, bool assignGhostRole);
static void (*orig_Revive)(void *__this);

// Roles
static void (*orig_SetRole)(void *__this, void *targetPlayer, int32_t role);
static int32_t (*orig_get_Role)(void *__this);
static bool (*orig_IsRole)(void *__this, int32_t role);
static bool (*orig_CanReport)(void *__this);
static bool (*orig_CanVent)(void *__this);

// Cosmetics (HatManager)
static bool (*orig_get_HasUnlocked)(void *__this);
static bool (*orig_GetPurchaseStatus)(void *__this, void *productId);
static void *(*orig_get_GoldHats)(void *__this);           // GetUnlockedHats
static void *(*orig_get_Skins)(void *__this);              // get_AllSkins
static void *(*orig_get_Pets)(void *__this);               // get_AllPets

// Vision, Chat, Host
static float (*orig_CalculateLightRadius)(void *__this, void *player);  // ShipStatus virtual
static float (*orig_get_Vision)(void *__this);
static void (*orig_HudUpdate)(void *__this);
static void (*orig_SendChat)(void *__this);
static bool (*orig_get_AmHost)(void *__this);
static void (*orig_RpcStartGame)(void *__this);
static void (*orig_EndGame)(void *__this, int32_t endReason, bool showAd);
static void (*orig_SyncSettings)(void *__this, void *options);

// ─────────────────────────────────────────────────────────────────────────────
//  PLAYER LOGIC HOOKS
// ─────────────────────────────────────────────────────────────────────────────

static void hook_FixedUpdate_repl(void *__this) {
    orig_FixedUpdate(__this);

    if (!g_toggles.noClip && !g_toggles.autoKill && !g_toggles.showGhosts &&
        !g_toggles.forceStart && !g_toggles.spamChat)
        return;

    // noClip – keep CanMove alive every frame (defence against server-side checks)
    // autoKill – murder nearest player if forceImposter is active (basic implementation)
    // showGhosts – typically handled by hooking visibility checks

    if (g_toggles.forceStart) {
        // Call RpcStartGame every frame (game will ignore extra calls once started)
        // This is a simplified example; real impl. would find AmongUsClient instance.
    }

    if (g_toggles.spamChat) {
        // Re-send the last chat message every 60 frames (pseudo)
    }
}

static void hook_SetKillTimer_repl(void *__this, float cooldown) {
    if (g_toggles.noKillCooldown) {
        cooldown = 0.0f;
    }
    orig_SetKillTimer(__this, cooldown);
}

static void hook_MurderPlayer_repl(void *__this, void *target, int32_t resultFlags) {
    if (!g_toggles.autoKill && target == __this) return;
    orig_MurderPlayer(__this, target, resultFlags);
}

static void hook_RpcCompleteTask_repl(void *__this, uint32_t taskId) {
    if (g_toggles.instantTasks) {
        // Optionally skip calling original to prevent server sync.
        return;
    }
    orig_RpcCompleteTask(__this, taskId);
}

static bool hook_get_IsImposter_repl(void *__this) {
    if (g_toggles.forceImposter) return true;
    return orig_get_IsImposter(__this);
}

static bool hook_IsImposter_repl(void *__this) {
    if (g_toggles.forceImposter) return true;
    return orig_IsImposter(__this);
}

static void *hook_get_Data_repl(void *__this) {
    return orig_get_Data(__this);
}

static bool hook_CanMove_repl(void *__this) {
    if (g_toggles.noClip) return true;
    return orig_CanMove(__this);
}

static void hook_Die_repl(void *__this, int32_t reason, bool assignGhostRole) {
    if (g_toggles.godMode) return;
    orig_Die(__this, reason, assignGhostRole);
}

static void hook_Revive_repl(void *__this) {
    orig_Revive(__this);
}

// ─────────────────────────────────────────────────────────────────────────────
//  ROLE HOOKS
// ─────────────────────────────────────────────────────────────────────────────

static void hook_SetRole_repl(void *__this, void *targetPlayer, int32_t role) {
    orig_SetRole(__this, targetPlayer, role);
}

static int32_t hook_get_Role_repl(void *__this) {
    return orig_get_Role(__this);
}

static bool hook_IsRole_repl(void *__this, int32_t role) {
    return orig_IsRole(__this, role);
}

static bool hook_CanReport_repl(void *__this) {
    if (g_toggles.forceImposter) return true;  // imposters can always report
    return orig_CanReport(__this);
}

static bool hook_CanVent_repl(void *__this) {
    if (g_toggles.forceImposter) return true;  // imposters can always vent
    return orig_CanVent(__this);
}

// ─────────────────────────────────────────────────────────────────────────────
//  COSMETIC UNLOCK HOOKS
// ─────────────────────────────────────────────────────────────────────────────

static bool hook_get_HasUnlocked_repl(void *__this) {
    if (g_toggles.unlockAll) return true;
    return orig_get_HasUnlocked(__this);
}

static bool hook_GetPurchaseStatus_repl(void *__this, void *productId) {
    if (g_toggles.freePurchases) return true;
    return orig_GetPurchaseStatus(__this, productId);
}

static void *hook_get_GoldHats_repl(void *__this) {
    return orig_get_GoldHats(__this);
}

static void *hook_get_Skins_repl(void *__this) {
    return orig_get_Skins(__this);
}

static void *hook_get_Pets_repl(void *__this) {
    return orig_get_Pets(__this);
}

// ─────────────────────────────────────────────────────────────────────────────
//  VISION HOOKS
// ─────────────────────────────────────────────────────────────────────────────

static float hook_CalculateLightRadius_repl(void *__this, void *player) {
    if (g_toggles.maxVision) return 1000.0f;
    return orig_CalculateLightRadius(__this, player);
}

static float hook_get_Vision_repl(void *__this) {
    if (g_toggles.maxVision) return 10.0f;     // max light modifier
    return orig_get_Vision(__this);
}

// ─────────────────────────────────────────────────────────────────────────────
//  HUD & CHAT HOOKS
// ─────────────────────────────────────────────────────────────────────────────

static void hook_HudUpdate_repl(void *__this) {
    orig_HudUpdate(__this);

    // If showRoles is on, draw role labels above players.
    // This would involve iterating PlayerControl instances and
    // rendering text via the game's own text components or via ImGui.
}

static void hook_SendChat_repl(void *__this) {
    if (g_toggles.bypassFilters) {
        // Modify freeChatField.text before calling original
    }
    orig_SendChat(__this);
}

// ─────────────────────────────────────────────────────────────────────────────
//  HOST HOOKS
// ─────────────────────────────────────────────────────────────────────────────

static bool hook_get_AmHost_repl(void *__this) {
    if (g_toggles.alwaysHost) return true;
    return orig_get_AmHost(__this);
}

static void hook_RpcStartGame_repl(void *__this) {
    orig_RpcStartGame(__this);
}

static void hook_EndGame_repl(void *__this, int32_t endReason, bool showAd) {
    orig_EndGame(__this, endReason, showAd);
}

static void hook_SyncSettings_repl(void *__this, void *options) {
    orig_SyncSettings(__this, options);
}

// ─────────────────────────────────────────────────────────────────────────────
//  HOOK REGISTRATORS  –  called once from TweakEntry.mm constructor.
//  Leaves a placeholder even when offset is 0x0 so you just need to
//  fill O_* values in MalumMenu.c (or a offsets.c) and recompile.
// ─────────────────────────────────────────────────────────────────────────────

#define TRY_HOOK(offset, replace, origPtr) \
    do { \
        if ((offset) != 0x0) { \
            IL2Hook((offset), (void *)(replace), (void **)(origPtr)); \
        } \
    } while (0)

void hook_FixedUpdate(void)         { TRY_HOOK(O_FixedUpdate,         hook_FixedUpdate_repl,        &orig_FixedUpdate); }
void hook_SetKillTimer(void)        { TRY_HOOK(O_SetKillTimer,        hook_SetKillTimer_repl,       &orig_SetKillTimer); }
void hook_MurderPlayer(void)        { TRY_HOOK(O_MurderPlayer,        hook_MurderPlayer_repl,       &orig_MurderPlayer); }
void hook_RpcCompleteTask(void)     { TRY_HOOK(O_RpcCompleteTask,     hook_RpcCompleteTask_repl,    &orig_RpcCompleteTask); }
void hook_get_IsImposter(void)      { TRY_HOOK(O_get_IsImposter,      hook_get_IsImposter_repl,     &orig_get_IsImposter); }
void hook_IsImposter(void)          { TRY_HOOK(O_IsImposter,          hook_IsImposter_repl,         &orig_IsImposter); }
void hook_get_Data(void)            { TRY_HOOK(O_get_Data,            hook_get_Data_repl,           &orig_get_Data); }
void hook_CanMove(void)             { TRY_HOOK(O_CanMove,             hook_CanMove_repl,            &orig_CanMove); }
void hook_Die(void)                 { TRY_HOOK(O_Die,                 hook_Die_repl,                &orig_Die); }
void hook_Revive(void)              { TRY_HOOK(O_Revive,              hook_Revive_repl,             &orig_Revive); }

void hook_SetRole(void)             { TRY_HOOK(O_SetRole,             hook_SetRole_repl,            &orig_SetRole); }
void hook_get_Role(void)            { TRY_HOOK(O_get_Role,            hook_get_Role_repl,           &orig_get_Role); }
void hook_IsRole(void)              { TRY_HOOK(O_IsRole,              hook_IsRole_repl,             &orig_IsRole); }
void hook_CanReport(void)           { TRY_HOOK(O_CanReport,           hook_CanReport_repl,          &orig_CanReport); }
void hook_CanVent(void)             { TRY_HOOK(O_CanVent,             hook_CanVent_repl,            &orig_CanVent); }

void hook_get_HasUnlocked(void)     { TRY_HOOK(O_get_HasUnlocked,     hook_get_HasUnlocked_repl,    &orig_get_HasUnlocked); }
void hook_GetPurchaseStatus(void)   { TRY_HOOK(O_GetPurchaseStatus,   hook_GetPurchaseStatus_repl,  &orig_GetPurchaseStatus); }
void hook_get_GoldHats(void)        { TRY_HOOK(O_get_GoldHats,        hook_get_GoldHats_repl,       &orig_get_GoldHats); }
void hook_get_Skins(void)           { TRY_HOOK(O_get_Skins,           hook_get_Skins_repl,          &orig_get_Skins); }
void hook_get_Pets(void)            { TRY_HOOK(O_get_Pets,            hook_get_Pets_repl,           &orig_get_Pets); }

void hook_CalculateLightRadius(void){ TRY_HOOK(O_CalculateLightRadius,hook_CalculateLightRadius_repl,&orig_CalculateLightRadius); }
void hook_get_Vision(void)          { TRY_HOOK(O_get_Vision,          hook_get_Vision_repl,         &orig_get_Vision); }
void hook_HudUpdate(void)           { TRY_HOOK(O_HudUpdate,           hook_HudUpdate_repl,          &orig_HudUpdate); }
void hook_SendChat(void)            { TRY_HOOK(O_SendChat,            hook_SendChat_repl,           &orig_SendChat); }
void hook_get_AmHost(void)          { TRY_HOOK(O_get_AmHost,          hook_get_AmHost_repl,         &orig_get_AmHost); }
void hook_RpcStartGame(void)        { TRY_HOOK(O_RpcStartGame,        hook_RpcStartGame_repl,       &orig_RpcStartGame); }
void hook_EndGame(void)             { TRY_HOOK(O_EndGame,             hook_EndGame_repl,            &orig_EndGame); }
void hook_SyncSettings(void)        { TRY_HOOK(O_SyncSettings,        hook_SyncSettings_repl,       &orig_SyncSettings); }
