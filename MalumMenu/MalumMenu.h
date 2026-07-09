#pragma once

#include <stdint.h>
#include <stdbool.h>
#include <mach-o/dyld.h>

// ═══════════════════════════════════════════════════════════════════════════════
//  OFFSET DECLARATIONS – defined in TweakEntry.mm
// ═══════════════════════════════════════════════════════════════════════════════

extern uintptr_t O_FixedUpdate;
extern uintptr_t O_SetKillTimer;
extern uintptr_t O_MurderPlayer;
extern uintptr_t O_RpcCompleteTask;
extern uintptr_t O_RpcSetRole;
extern uintptr_t O_RpcSyncSettings;
extern uintptr_t O_PlayerPhysicsFixedUpdate;
extern uintptr_t O_PlayerPhysicsLateUpdate;
extern uintptr_t O_PlayerPhysicsHandleAnimation;
extern uintptr_t O_PlayerPhysicsCoEnterVent;
extern uintptr_t O_PlayerPhysicsCoExitVent;
extern uintptr_t O_ShipStatusFixedUpdate;
extern uintptr_t O_ShipStatusCalculateLightRadius;
extern uintptr_t O_ShipStatusUpdateSystem;
extern uintptr_t O_HudManagerUpdate;
extern uintptr_t O_AmongUsClientUpdate;
extern uintptr_t O_AmongUsClientOnGameJoined;
extern uintptr_t O_AmongUsClientStartGame;
extern uintptr_t O_MeetingHudUpdate;
extern uintptr_t O_MeetingHudVotingComplete;
extern uintptr_t O_MeetingHudClose;
extern uintptr_t O_MeetingHudCastVote;
extern uintptr_t O_MeetingHudServerStart;
extern uintptr_t O_MeetingHudDeserialize;
extern uintptr_t O_GameManagerCanReportBodies;
extern uintptr_t O_GameManagerRpcEndGame;
extern uintptr_t O_GameStartManagerUpdate;
extern uintptr_t O_GameDataGetPlayerById;
extern uintptr_t O_ChatControllerSendChat;
extern uintptr_t O_RoleBehaviourGetIsImpostor;
extern uintptr_t O_RoleManagerIsImpostorRole;
extern uintptr_t O_RoleManagerSetRole;
extern uintptr_t O_PlayerControlGetData;
extern uintptr_t O_PlayerControlCanMove;
extern uintptr_t O_PlayerControlDie;
extern uintptr_t O_PlayerControlRevive;
extern uintptr_t O_HatManagerGetUnlockedPets;
extern uintptr_t O_HatManagerGetUnlockedHats;
extern uintptr_t O_HatManagerAllSkins;
extern uintptr_t O_HatManagerAllPets;
extern uintptr_t O_CustomizationDataSetName;
extern uintptr_t O_CustomizationDataSetHat;
extern uintptr_t O_CustomizationDataSetVisor;
extern uintptr_t O_CustomizationDataSetSkin;
extern uintptr_t O_CustomizationDataSetPet;
extern uintptr_t O_CustomizationDataSetNamePlate;
extern uintptr_t O_InnerNetClientAmHost;
extern uintptr_t O_BanMenuSetVisible;
extern uintptr_t O_AccountManagerCanPlayOnline;
extern uintptr_t O_PingTrackerUpdate;
extern uintptr_t O_SceneManagerInternalSceneLoaded;

// ═══════════════════════════════════════════════════════════════════════════════
//  TOGGLES – one bool per cheat, matching original MalumMenu CheatToggles
// ═══════════════════════════════════════════════════════════════════════════════

typedef struct {
    // ── General (always-on at start) ──
    bool unlockFeatures;
    bool freeCosmetics;
    bool avoidPenalties;

    // ── Movement ──
    bool noClip;
    bool teleportCursor;
    bool invertControls;
    bool moonWalk;
    bool adjustSpeed;
    bool freeAirshipDoors;
    bool resetDoors;
    bool openAllDoors;
    bool pinPlayer;
    bool keyStuck;
    bool sizeHack;
    bool wallPull;
    bool wallPullKill;
    bool noClipVent;
    bool restoreDefaultSpeed;
    bool adjustMovement;

    // ── Combat ──
    bool noKillCd;
    bool killAnyone;
    bool killReach;
    bool noKillRange;
    bool killRange;
    bool noKillAnim;
    bool killAll;
    bool dontKill;
    bool killKiller;
    bool killReport;
    bool adjustKillDistance;
    bool completeMyTasks;

    // ── Visual / ESP ──
    bool wallHack;
    bool noShadows;
    bool showAllPlayers;
    bool showGhosts;
    bool seeGhosts;
    bool showProtect;
    bool showVitals;
    bool showName;
    bool adjustColor;
    bool adjustOpacity;
    bool revealRoles;
    bool seeRoles;
    bool seeDisguises;
    bool revealVotes;
    bool espEnabled;
    bool espShowDistance;
    bool espColorByRole;
    bool espShowName;
    bool espShowRole;
    bool espShowDead;
    bool espShowVents;
    bool espShowSabotage;
    bool espShowTasks;

    // ── Chat ──
    bool adjustChat;
    bool noChatCooldown;
    bool forcePrivateChat;
    bool allowAllChatTypes;
    bool chatAsAnyColor;
    bool checkChat;
    bool longerMessages;
    bool bypassUrlBlock;
    bool lowerRateLimits;
    bool enableChat;

    // ── Ship / Sabotage ──
    bool sabotageAll;
    bool fixAllSabotages;
    bool alwaysRepair;
    bool closeDoors;
    bool openDoors;
    bool doorsTimed;
    bool reactorTime;
    bool lightsAlwaysOn;
    bool commsAlwaysOn;
    bool oxygenAlwaysOn;
    bool reactorDelay;
    bool lightsAlwaysOff;
    bool closeMeeting;
    bool skipMeeting;
    bool callMeeting;
    bool unlockVents;
    bool walkInVents;
    bool autoOpenDoorsOnUse;

    // ── Host ──
    bool forceHost;
    bool forceHostName;
    bool forceStart;
    bool forceStartGame;
    bool forceEnd;
    bool kickPlayer;
    bool banPlayer;
    bool kickBanAll;
    bool autoStart;
    bool autoStartCount;
    bool autoStartTimer;
    bool endGame;
    bool endGameCrew;
    bool endGameImp;
    bool endGameDraw;
    bool exilePlayer;
    bool syncSettings;
    bool voteImmune;
    bool noGameEnd;
    bool noOptionsLimits;

    // ── Vents ──
    bool ventAll;
    bool ventInstant;
    bool ventNoAnim;
    bool ventKill;
    bool kickVents;

    // ── Sabotage ──
    bool noSabotageCd;
    bool sabotageAnywhere;
    bool instantSabotage;

    // ── Role cheats ──
    bool endlessSsDuration;
    bool noShapeshiftAnim;
    bool endlessVentTime;
    bool noVentCooldown;
    bool noVitalsCooldown;
    bool endlessBattery;
    bool noTrackingCooldown;
    bool endlessTracking;
} MenuToggles;

extern MenuToggles g_toggles;
extern bool g_showMenu;
extern bool g_hooksReady;

// ═══════════════════════════════════════════════════════════════════════════════
//  HOOK DECLARATIONS – implementations in Hooks.mm
// ═══════════════════════════════════════════════════════════════════════════════

// Core Updates
extern "C" void hook_FixedUpdate(void);
extern "C" void hook_SetKillTimer(void);
extern "C" void hook_MurderPlayer(void);
extern "C" void hook_RpcCompleteTask(void);
extern "C" void hook_RpcSetRole(void);
extern "C" void hook_RpcSyncSettings(void);
extern "C" void hook_PlayerPhysicsFixedUpdate(void);
extern "C" void hook_PlayerPhysicsLateUpdate(void);
extern "C" void hook_PlayerPhysicsHandleAnimation(void);
extern "C" void hook_PlayerPhysicsCoEnterVent(void);
extern "C" void hook_PlayerPhysicsCoExitVent(void);
extern "C" void hook_ShipStatusFixedUpdate(void);
extern "C" void hook_ShipStatusCalculateLightRadius(void);
extern "C" void hook_ShipStatusUpdateSystem(void);
extern "C" void hook_HudManagerUpdate(void);
extern "C" void hook_AmongUsClientUpdate(void);
extern "C" void hook_AmongUsClientOnGameJoined(void);
extern "C" void hook_AmongUsClientStartGame(void);

// Meetings
extern "C" void hook_MeetingHudUpdate(void);
extern "C" void hook_MeetingHudVotingComplete(void);
extern "C" void hook_MeetingHudClose(void);
extern "C" void hook_MeetingHudCastVote(void);
extern "C" void hook_MeetingHudServerStart(void);
extern "C" void hook_MeetingHudDeserialize(void);

// Game logic
extern "C" void hook_GameManagerCanReportBodies(void);
extern "C" void hook_GameManagerRpcEndGame(void);
extern "C" void hook_GameStartManagerUpdate(void);
extern "C" void hook_GameDataGetPlayerById(void);

// Chat
extern "C" void hook_ChatControllerSendChat(void);

// Roles
extern "C" void hook_RoleBehaviourGetIsImpostor(void);
extern "C" void hook_RoleManagerIsImpostorRole(void);
extern "C" void hook_RoleManagerSetRole(void);

// Player
extern "C" void hook_PlayerControlGetData(void);
extern "C" void hook_PlayerControlCanMove(void);
extern "C" void hook_PlayerControlDie(void);
extern "C" void hook_PlayerControlRevive(void);

// Cosmetics
extern "C" void hook_HatManagerGetUnlockedPets(void);
extern "C" void hook_HatManagerGetUnlockedHats(void);
extern "C" void hook_HatManagerAllSkins(void);
extern "C" void hook_HatManagerAllPets(void);
extern "C" void hook_CustomizationDataSetName(void);
extern "C" void hook_CustomizationDataSetHat(void);
extern "C" void hook_CustomizationDataSetVisor(void);
extern "C" void hook_CustomizationDataSetSkin(void);
extern "C" void hook_CustomizationDataSetPet(void);
extern "C" void hook_CustomizationDataSetNamePlate(void);

// Host / Misc
extern "C" void hook_InnerNetClientAmHost(void);
extern "C" void hook_BanMenuSetVisible(void);
extern "C" void hook_AccountManagerCanPlayOnline(void);
extern "C" void hook_PingTrackerUpdate(void);
extern "C" void hook_SceneManagerInternalSceneLoaded(void);

// ═══════════════════════════════════════════════════════════════════════════════
//  UTILITY
// ═══════════════════════════════════════════════════════════════════════════════

static inline uintptr_t get_unity_base(void) {
    return (uintptr_t)_dyld_get_image_vmaddr_slide(0);
}
