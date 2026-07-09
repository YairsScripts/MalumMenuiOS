#import "MalumMenu.h"
#include "IL2Hook.h"

// ═══════════════════════════════════════════════════════════════════════════════
//  ORIGINAL FUNCTION POINTERS
// ═══════════════════════════════════════════════════════════════════════════════

// Core Updates
static void (*orig_FixedUpdate)(void *__this);
static void (*orig_SetKillTimer)(void *__this, float cooldown);
static void (*orig_MurderPlayer)(void *__this, void *target, int32_t resultFlags);
static void (*orig_RpcCompleteTask)(void *__this, uint32_t taskId);
static void (*orig_RpcSetRole)(void *__this, void *targetPlayer, int32_t role);
static void (*orig_RpcSyncSettings)(void *__this, void *options);
static void (*orig_PlayerPhysicsFixedUpdate)(void *__this);
static void (*orig_PlayerPhysicsLateUpdate)(void *__this);
static void (*orig_PlayerPhysicsHandleAnimation)(void *__this);
static void (*orig_PlayerPhysicsCoEnterVent)(void *__this, int32_t id);
static void (*orig_PlayerPhysicsCoExitVent)(void *__this, int32_t id);
static void (*orig_ShipStatusFixedUpdate)(void *__this);
static float (*orig_ShipStatusCalculateLightRadius)(void *__this, void *player);
static void (*orig_ShipStatusUpdateSystem)(void *__this, int32_t systemType, void *msg);
static void (*orig_HudManagerUpdate)(void *__this);
static void (*orig_AmongUsClientUpdate)(void *__this);
static void (*orig_AmongUsClientOnGameJoined)(void *__this, void *gameIdString);
static void (*orig_AmongUsClientStartGame)(void *__this);

// Meetings
static void (*orig_MeetingHudUpdate)(void *__this);
static void (*orig_MeetingHudVotingComplete)(void *__this, void *states);
static void (*orig_MeetingHudClose)(void *__this);
static void (*orig_MeetingHudCastVote)(void *__this, void *voterId, void *suspectIdx);
static void (*orig_MeetingHudServerStart)(void *__this, void *reader);
static void (*orig_MeetingHudDeserialize)(void *__this, void *reader, bool initialState);

// Game logic
static bool (*orig_GameManagerCanReportBodies)(void *__this);
static void (*orig_GameManagerRpcEndGame)(void *__this, int32_t endReason, bool showAd);
static void (*orig_GameStartManagerUpdate)(void *__this);
static void *(*orig_GameDataGetPlayerById)(void *__this, uint8_t playerId);

// Chat
static void (*orig_ChatControllerSendChat)(void *__this);

// Roles
static bool (*orig_RoleBehaviourGetIsImpostor)(void *__this);
static bool (*orig_RoleManagerIsImpostorRole)(void *__this, int32_t role);
static void (*orig_RoleManagerSetRole)(void *__this, void *targetPlayer, int32_t role);

// Player
static void *(*orig_PlayerControlGetData)(void *__this);
static bool (*orig_PlayerControlCanMove)(void *__this);
static void (*orig_PlayerControlDie)(void *__this, int32_t reason, bool assignGhostRole);
static void (*orig_PlayerControlRevive)(void *__this);

// Cosmetics
static bool (*orig_HatManagerGetUnlockedPets)(void *__this);
static bool (*orig_HatManagerGetUnlockedHats)(void *__this);
static void *(*orig_HatManagerAllSkins)(void *__this);
static void *(*orig_HatManagerAllPets)(void *__this);
static void (*orig_CustomizationDataSetName)(void *__this, void *value);
static void (*orig_CustomizationDataSetHat)(void *__this, void *value);
static void (*orig_CustomizationDataSetVisor)(void *__this, void *value);
static void (*orig_CustomizationDataSetSkin)(void *__this, void *value);
static void (*orig_CustomizationDataSetPet)(void *__this, void *value);
static void (*orig_CustomizationDataSetNamePlate)(void *__this, void *value);

// Host / Misc
static bool (*orig_InnerNetClientAmHost)(void *__this);
static void (*orig_BanMenuSetVisible)(void *__this, bool show);
static bool (*orig_AccountManagerCanPlayOnline)(void *__this);
static void (*orig_PingTrackerUpdate)(void *__this);
static void (*orig_SceneManagerInternalSceneLoaded)(void *__this, void *scene, void *mode);

// ═══════════════════════════════════════════════════════════════════════════════
//  PLAYER CONTROL HOOKS
// ═══════════════════════════════════════════════════════════════════════════════

static void hook_FixedUpdate_repl(void *__this) {
    orig_FixedUpdate(__this);
}

static void hook_SetKillTimer_repl(void *__this, float cooldown) {
    if (g_toggles.noKillCd) {
        cooldown = 0.0f;
    }
    orig_SetKillTimer(__this, cooldown);
}

static void hook_MurderPlayer_repl(void *__this, void *target, int32_t resultFlags) {
    orig_MurderPlayer(__this, target, resultFlags);
}

static void hook_RpcCompleteTask_repl(void *__this, uint32_t taskId) {
    if (g_toggles.completeMyTasks) {
        return;
    }
    orig_RpcCompleteTask(__this, taskId);
}

static void hook_RpcSetRole_repl(void *__this, void *targetPlayer, int32_t role) {
    orig_RpcSetRole(__this, targetPlayer, role);
}

static void hook_RpcSyncSettings_repl(void *__this, void *options) {
    if (g_toggles.noOptionsLimits) return;
    orig_RpcSyncSettings(__this, options);
}

static void *hook_PlayerControlGetData_repl(void *__this) {
    return orig_PlayerControlGetData(__this);
}

static bool hook_PlayerControlCanMove_repl(void *__this) {
    if (g_toggles.noClip) return true;
    return orig_PlayerControlCanMove(__this);
}

static void hook_PlayerControlDie_repl(void *__this, int32_t reason, bool assignGhostRole) {
    if (g_toggles.avoidPenalties) return;
    orig_PlayerControlDie(__this, reason, assignGhostRole);
}

static void hook_PlayerControlRevive_repl(void *__this) {
    orig_PlayerControlRevive(__this);
}

// ═══════════════════════════════════════════════════════════════════════════════
//  PLAYER PHYSICS HOOKS
// ═══════════════════════════════════════════════════════════════════════════════

static void hook_PlayerPhysicsFixedUpdate_repl(void *__this) {
    orig_PlayerPhysicsFixedUpdate(__this);
}

static void hook_PlayerPhysicsLateUpdate_repl(void *__this) {
    orig_PlayerPhysicsLateUpdate(__this);

    if (g_toggles.noClip && __this != 0) {
        // PlayerPhysics.myPlayer.Collider.enabled = false
    }
}

static void hook_PlayerPhysicsHandleAnimation_repl(void *__this) {
    if (g_toggles.moonWalk) {
        return;
    }
    orig_PlayerPhysicsHandleAnimation(__this);
}

static void hook_PlayerPhysicsCoEnterVent_repl(void *__this, int32_t id) {
    orig_PlayerPhysicsCoEnterVent(__this, id);
}

static void hook_PlayerPhysicsCoExitVent_repl(void *__this, int32_t id) {
    orig_PlayerPhysicsCoExitVent(__this, id);
}

// ═══════════════════════════════════════════════════════════════════════════════
//  NON-VOID RETURNING HOOKS
// ═══════════════════════════════════════════════════════════════════════════════

static bool hook_GameManagerCanReportBodies_repl(void *__this) {
    return orig_GameManagerCanReportBodies(__this);
}

static void *hook_GameDataGetPlayerById_repl(void *__this, uint8_t playerId) {
    return orig_GameDataGetPlayerById(__this, playerId);
}

static bool hook_RoleBehaviourGetIsImpostor_repl(void *__this) {
    return orig_RoleBehaviourGetIsImpostor(__this);
}

static bool hook_RoleManagerIsImpostorRole_repl(void *__this, int32_t role) {
    return orig_RoleManagerIsImpostorRole(__this, role);
}

static bool hook_InnerNetClientAmHost_repl(void *__this) {
    return orig_InnerNetClientAmHost(__this);
}

static bool hook_AccountManagerCanPlayOnline_repl(void *__this) {
    if (g_toggles.unlockFeatures) return true;
    return orig_AccountManagerCanPlayOnline(__this);
}

static bool hook_HatManagerGetUnlockedPets_repl(void *__this) {
    if (g_toggles.freeCosmetics) return true;
    return orig_HatManagerGetUnlockedPets(__this);
}

static bool hook_HatManagerGetUnlockedHats_repl(void *__this) {
    if (g_toggles.freeCosmetics) return true;
    return orig_HatManagerGetUnlockedHats(__this);
}

static void *hook_HatManagerAllSkins_repl(void *__this) {
    return orig_HatManagerAllSkins(__this);
}

static void *hook_HatManagerAllPets_repl(void *__this) {
    return orig_HatManagerAllPets(__this);
}

// ═══════════════════════════════════════════════════════════════════════════════
//  SHIP STATUS HOOKS
// ═══════════════════════════════════════════════════════════════════════════════

static void hook_ShipStatusFixedUpdate_repl(void *__this) {
    orig_ShipStatusFixedUpdate(__this);

    if (g_toggles.closeMeeting) {
        g_toggles.closeMeeting = false;
    }

    if (g_toggles.skipMeeting) {
        g_toggles.skipMeeting = false;
    }

    if (g_toggles.callMeeting) {
        g_toggles.callMeeting = false;
    }

    if (g_toggles.walkInVents && __this != 0) {
        // PlayerControl.LocalPlayer.inVent = false
        // PlayerControl.LocalPlayer.moveable = true
    }

    if (g_toggles.kickVents) {
        g_toggles.kickVents = false;
    }
}

static float hook_ShipStatusCalculateLightRadius_repl(void *__this, void *player) {
    if (g_toggles.noShadows) return 1000.0f;
    return orig_ShipStatusCalculateLightRadius(__this, player);
}

static void hook_ShipStatusUpdateSystem_repl(void *__this, int32_t systemType, void *msg) {
    orig_ShipStatusUpdateSystem(__this, systemType, msg);
}

// ═══════════════════════════════════════════════════════════════════════════════
//  HUD MANAGER HOOKS
// ═══════════════════════════════════════════════════════════════════════════════

static void hook_HudManagerUpdate_repl(void *__this) {
    orig_HudManagerUpdate(__this);

    if (g_toggles.noShadows) {
        // ShadowQuad.gameObject.SetActive(false)
    }

    if (g_toggles.enableChat) {
        // Chat.gameObject.SetActive(true)
    }

    if (g_toggles.unlockVents && __this != 0) {
        // ImpostorVentButton.gameObject.SetActive(true)
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  AMONG US CLIENT HOOKS
// ═══════════════════════════════════════════════════════════════════════════════

static void hook_AmongUsClientUpdate_repl(void *__this) {
    orig_AmongUsClientUpdate(__this);
}

static void hook_AmongUsClientOnGameJoined_repl(void *__this, void *gameIdString) {
    orig_AmongUsClientOnGameJoined(__this, gameIdString);
}

static void hook_AmongUsClientStartGame_repl(void *__this) {
    orig_AmongUsClientStartGame(__this);
}

// ═══════════════════════════════════════════════════════════════════════════════
//  MEETING HUD HOOKS
// ═══════════════════════════════════════════════════════════════════════════════

static void hook_MeetingHudUpdate_repl(void *__this) {
    if (g_toggles.revealVotes && __this != 0) {
        // Bloop vote icons + set vote spreader active
    }
    orig_MeetingHudUpdate(__this);
}

static void hook_MeetingHudVotingComplete_repl(void *__this, void *states) {
    orig_MeetingHudVotingComplete(__this, states);
}

static void hook_MeetingHudClose_repl(void *__this) {
    orig_MeetingHudClose(__this);
}

static void hook_MeetingHudCastVote_repl(void *__this, void *voterId, void *suspectIdx) {
    orig_MeetingHudCastVote(__this, voterId, suspectIdx);
}

static void hook_MeetingHudServerStart_repl(void *__this, void *reader) {
    orig_MeetingHudServerStart(__this, reader);
}

static void hook_MeetingHudDeserialize_repl(void *__this, void *reader, bool initialState) {
    orig_MeetingHudDeserialize(__this, reader, initialState);
}

// ═══════════════════════════════════════════════════════════════════════════════
//  GAME LOGIC HOOKS
// ═══════════════════════════════════════════════════════════════════════════════

static void hook_GameManagerRpcEndGame_repl(void *__this, int32_t endReason, bool showAd) {
    if (g_toggles.noGameEnd) return;
    orig_GameManagerRpcEndGame(__this, endReason, showAd);
}

static void hook_GameStartManagerUpdate_repl(void *__this) {
    orig_GameStartManagerUpdate(__this);
}

// ═══════════════════════════════════════════════════════════════════════════════
//  CHAT HOOKS
// ═══════════════════════════════════════════════════════════════════════════════

static void hook_ChatControllerSendChat_repl(void *__this) {
    orig_ChatControllerSendChat(__this);
}

// ═══════════════════════════════════════════════════════════════════════════════
//  ROLE LOGIC HOOKS
// ═══════════════════════════════════════════════════════════════════════════════

static void hook_RoleManagerSetRole_repl(void *__this, void *targetPlayer, int32_t role) {
    orig_RoleManagerSetRole(__this, targetPlayer, role);
}

// ═══════════════════════════════════════════════════════════════════════════════
//  COSMETIC / UNLOCK HOOKS
// ═══════════════════════════════════════════════════════════════════════════════

static void hook_CustomizationDataSetName_repl(void *__this, void *value) {
    orig_CustomizationDataSetName(__this, value);
}

static void hook_CustomizationDataSetHat_repl(void *__this, void *value) {
    orig_CustomizationDataSetHat(__this, value);
}

static void hook_CustomizationDataSetVisor_repl(void *__this, void *value) {
    orig_CustomizationDataSetVisor(__this, value);
}

static void hook_CustomizationDataSetSkin_repl(void *__this, void *value) {
    orig_CustomizationDataSetSkin(__this, value);
}

static void hook_CustomizationDataSetPet_repl(void *__this, void *value) {
    orig_CustomizationDataSetPet(__this, value);
}

static void hook_CustomizationDataSetNamePlate_repl(void *__this, void *value) {
    orig_CustomizationDataSetNamePlate(__this, value);
}

// ═══════════════════════════════════════════════════════════════════════════════
//  HOST / MISC HOOKS
// ═══════════════════════════════════════════════════════════════════════════════

static void hook_BanMenuSetVisible_repl(void *__this, bool show) {
    if (__this == 0) return;
    orig_BanMenuSetVisible(__this, show);
}

static void hook_PingTrackerUpdate_repl(void *__this) {
    orig_PingTrackerUpdate(__this);
}

static void hook_SceneManagerInternalSceneLoaded_repl(void *__this, void *scene, void *mode) {
    orig_SceneManagerInternalSceneLoaded(__this, scene, mode);
}

// ═══════════════════════════════════════════════════════════════════════════════
//  HOOK REGISTRATORS
// ═══════════════════════════════════════════════════════════════════════════════

#define TRY_HOOK(offset, replace, origPtr) \
    do { \
        if ((offset) != 0x0) { \
            HookFunction((offset), (void *)(replace), (void **)(origPtr)); \
        } \
    } while (0)

// Core Updates
void hook_FixedUpdate(void)                    { TRY_HOOK(O_FixedUpdate, hook_FixedUpdate_repl, &orig_FixedUpdate); }
void hook_SetKillTimer(void)                   { TRY_HOOK(O_SetKillTimer, hook_SetKillTimer_repl, &orig_SetKillTimer); }
void hook_MurderPlayer(void)                   { TRY_HOOK(O_MurderPlayer, hook_MurderPlayer_repl, &orig_MurderPlayer); }
void hook_RpcCompleteTask(void)                { TRY_HOOK(O_RpcCompleteTask, hook_RpcCompleteTask_repl, &orig_RpcCompleteTask); }
void hook_RpcSetRole(void)                     { TRY_HOOK(O_RpcSetRole, hook_RpcSetRole_repl, &orig_RpcSetRole); }
void hook_RpcSyncSettings(void)                { TRY_HOOK(O_RpcSyncSettings, hook_RpcSyncSettings_repl, &orig_RpcSyncSettings); }
void hook_PlayerPhysicsFixedUpdate(void)       { TRY_HOOK(O_PlayerPhysicsFixedUpdate, hook_PlayerPhysicsFixedUpdate_repl, &orig_PlayerPhysicsFixedUpdate); }
void hook_PlayerPhysicsLateUpdate(void)        { TRY_HOOK(O_PlayerPhysicsLateUpdate, hook_PlayerPhysicsLateUpdate_repl, &orig_PlayerPhysicsLateUpdate); }
void hook_PlayerPhysicsHandleAnimation(void)   { TRY_HOOK(O_PlayerPhysicsHandleAnimation, hook_PlayerPhysicsHandleAnimation_repl, &orig_PlayerPhysicsHandleAnimation); }
void hook_PlayerPhysicsCoEnterVent(void)       { TRY_HOOK(O_PlayerPhysicsCoEnterVent, hook_PlayerPhysicsCoEnterVent_repl, &orig_PlayerPhysicsCoEnterVent); }
void hook_PlayerPhysicsCoExitVent(void)        { TRY_HOOK(O_PlayerPhysicsCoExitVent, hook_PlayerPhysicsCoExitVent_repl, &orig_PlayerPhysicsCoExitVent); }
void hook_ShipStatusFixedUpdate(void)          { TRY_HOOK(O_ShipStatusFixedUpdate, hook_ShipStatusFixedUpdate_repl, &orig_ShipStatusFixedUpdate); }
void hook_ShipStatusCalculateLightRadius(void) { TRY_HOOK(O_ShipStatusCalculateLightRadius, hook_ShipStatusCalculateLightRadius_repl, &orig_ShipStatusCalculateLightRadius); }
void hook_ShipStatusUpdateSystem(void)         { TRY_HOOK(O_ShipStatusUpdateSystem, hook_ShipStatusUpdateSystem_repl, &orig_ShipStatusUpdateSystem); }
void hook_HudManagerUpdate(void)               { TRY_HOOK(O_HudManagerUpdate, hook_HudManagerUpdate_repl, &orig_HudManagerUpdate); }
void hook_AmongUsClientUpdate(void)            { TRY_HOOK(O_AmongUsClientUpdate, hook_AmongUsClientUpdate_repl, &orig_AmongUsClientUpdate); }
void hook_AmongUsClientOnGameJoined(void)      { TRY_HOOK(O_AmongUsClientOnGameJoined, hook_AmongUsClientOnGameJoined_repl, &orig_AmongUsClientOnGameJoined); }
void hook_AmongUsClientStartGame(void)         { TRY_HOOK(O_AmongUsClientStartGame, hook_AmongUsClientStartGame_repl, &orig_AmongUsClientStartGame); }

// Meetings
void hook_MeetingHudUpdate(void)               { TRY_HOOK(O_MeetingHudUpdate, hook_MeetingHudUpdate_repl, &orig_MeetingHudUpdate); }
void hook_MeetingHudVotingComplete(void)       { TRY_HOOK(O_MeetingHudVotingComplete, hook_MeetingHudVotingComplete_repl, &orig_MeetingHudVotingComplete); }
void hook_MeetingHudClose(void)                { TRY_HOOK(O_MeetingHudClose, hook_MeetingHudClose_repl, &orig_MeetingHudClose); }
void hook_MeetingHudCastVote(void)             { TRY_HOOK(O_MeetingHudCastVote, hook_MeetingHudCastVote_repl, &orig_MeetingHudCastVote); }
void hook_MeetingHudServerStart(void)          { TRY_HOOK(O_MeetingHudServerStart, hook_MeetingHudServerStart_repl, &orig_MeetingHudServerStart); }
void hook_MeetingHudDeserialize(void)          { TRY_HOOK(O_MeetingHudDeserialize, hook_MeetingHudDeserialize_repl, &orig_MeetingHudDeserialize); }

// Game logic
void hook_GameManagerCanReportBodies(void)     { TRY_HOOK(O_GameManagerCanReportBodies, hook_GameManagerCanReportBodies_repl, &orig_GameManagerCanReportBodies); }
void hook_GameManagerRpcEndGame(void)          { TRY_HOOK(O_GameManagerRpcEndGame, hook_GameManagerRpcEndGame_repl, &orig_GameManagerRpcEndGame); }
void hook_GameStartManagerUpdate(void)         { TRY_HOOK(O_GameStartManagerUpdate, hook_GameStartManagerUpdate_repl, &orig_GameStartManagerUpdate); }
void hook_GameDataGetPlayerById(void)          { TRY_HOOK(O_GameDataGetPlayerById, hook_GameDataGetPlayerById_repl, &orig_GameDataGetPlayerById); }

// Chat
void hook_ChatControllerSendChat(void)         { TRY_HOOK(O_ChatControllerSendChat, hook_ChatControllerSendChat_repl, &orig_ChatControllerSendChat); }

// Roles
void hook_RoleBehaviourGetIsImpostor(void)     { TRY_HOOK(O_RoleBehaviourGetIsImpostor, hook_RoleBehaviourGetIsImpostor_repl, &orig_RoleBehaviourGetIsImpostor); }
void hook_RoleManagerIsImpostorRole(void)      { TRY_HOOK(O_RoleManagerIsImpostorRole, hook_RoleManagerIsImpostorRole_repl, &orig_RoleManagerIsImpostorRole); }
void hook_RoleManagerSetRole(void)             { TRY_HOOK(O_RoleManagerSetRole, hook_RoleManagerSetRole_repl, &orig_RoleManagerSetRole); }

// Player
void hook_PlayerControlGetData(void)           { TRY_HOOK(O_PlayerControlGetData, hook_PlayerControlGetData_repl, &orig_PlayerControlGetData); }
void hook_PlayerControlCanMove(void)           { TRY_HOOK(O_PlayerControlCanMove, hook_PlayerControlCanMove_repl, &orig_PlayerControlCanMove); }
void hook_PlayerControlDie(void)               { TRY_HOOK(O_PlayerControlDie, hook_PlayerControlDie_repl, &orig_PlayerControlDie); }
void hook_PlayerControlRevive(void)            { TRY_HOOK(O_PlayerControlRevive, hook_PlayerControlRevive_repl, &orig_PlayerControlRevive); }

// Cosmetics
void hook_HatManagerGetUnlockedPets(void)      { TRY_HOOK(O_HatManagerGetUnlockedPets, hook_HatManagerGetUnlockedPets_repl, &orig_HatManagerGetUnlockedPets); }
void hook_HatManagerGetUnlockedHats(void)      { TRY_HOOK(O_HatManagerGetUnlockedHats, hook_HatManagerGetUnlockedHats_repl, &orig_HatManagerGetUnlockedHats); }
void hook_HatManagerAllSkins(void)             { TRY_HOOK(O_HatManagerAllSkins, hook_HatManagerAllSkins_repl, &orig_HatManagerAllSkins); }
void hook_HatManagerAllPets(void)              { TRY_HOOK(O_HatManagerAllPets, hook_HatManagerAllPets_repl, &orig_HatManagerAllPets); }
void hook_CustomizationDataSetName(void)       { TRY_HOOK(O_CustomizationDataSetName, hook_CustomizationDataSetName_repl, &orig_CustomizationDataSetName); }
void hook_CustomizationDataSetHat(void)        { TRY_HOOK(O_CustomizationDataSetHat, hook_CustomizationDataSetHat_repl, &orig_CustomizationDataSetHat); }
void hook_CustomizationDataSetVisor(void)      { TRY_HOOK(O_CustomizationDataSetVisor, hook_CustomizationDataSetVisor_repl, &orig_CustomizationDataSetVisor); }
void hook_CustomizationDataSetSkin(void)       { TRY_HOOK(O_CustomizationDataSetSkin, hook_CustomizationDataSetSkin_repl, &orig_CustomizationDataSetSkin); }
void hook_CustomizationDataSetPet(void)        { TRY_HOOK(O_CustomizationDataSetPet, hook_CustomizationDataSetPet_repl, &orig_CustomizationDataSetPet); }
void hook_CustomizationDataSetNamePlate(void)  { TRY_HOOK(O_CustomizationDataSetNamePlate, hook_CustomizationDataSetNamePlate_repl, &orig_CustomizationDataSetNamePlate); }

// Host / Misc
void hook_InnerNetClientAmHost(void)           { TRY_HOOK(O_InnerNetClientAmHost, hook_InnerNetClientAmHost_repl, &orig_InnerNetClientAmHost); }
void hook_BanMenuSetVisible(void)              { TRY_HOOK(O_BanMenuSetVisible, hook_BanMenuSetVisible_repl, &orig_BanMenuSetVisible); }
void hook_AccountManagerCanPlayOnline(void)    { TRY_HOOK(O_AccountManagerCanPlayOnline, hook_AccountManagerCanPlayOnline_repl, &orig_AccountManagerCanPlayOnline); }
void hook_PingTrackerUpdate(void)              { TRY_HOOK(O_PingTrackerUpdate, hook_PingTrackerUpdate_repl, &orig_PingTrackerUpdate); }
void hook_SceneManagerInternalSceneLoaded(void) { TRY_HOOK(O_SceneManagerInternalSceneLoaded, hook_SceneManagerInternalSceneLoaded_repl, &orig_SceneManagerInternalSceneLoaded); }
