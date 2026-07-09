#import "MalumMenu.h"
#import "FloatingOverlay.h"
#include <dispatch/dispatch.h>

extern "C" unsigned int sleep(unsigned int);

MenuToggles g_toggles     = {0};
bool         g_showMenu   = false;
bool         g_hooksReady = false;
int          g_hookSuccess = 0;
int          g_hookFailed  = 0;

// ── Core Updates ──
uintptr_t O_FixedUpdate                     = 0x1C449E4;
uintptr_t O_SetKillTimer                    = 0x1C439E4;
uintptr_t O_MurderPlayer                    = 0x1C4C5C4;
uintptr_t O_RpcCompleteTask                 = 0x1C518F4;
uintptr_t O_RpcSetRole                      = 0x1C519C4;
uintptr_t O_RpcSyncSettings                 = 0x1C52D5C;
uintptr_t O_PlayerPhysicsFixedUpdate        = 0x1C59F34;
uintptr_t O_PlayerPhysicsLateUpdate         = 0x1C5A74C;
uintptr_t O_PlayerPhysicsHandleAnimation    = 0x1C5A1C4;
uintptr_t O_PlayerPhysicsCoEnterVent        = 0x1C5B13C;
uintptr_t O_PlayerPhysicsCoExitVent         = 0x1C5B1C4;
uintptr_t O_ShipStatusFixedUpdate           = 0x1CCAEA8;
uintptr_t O_ShipStatusCalculateLightRadius  = 0x1CCB1C8;
uintptr_t O_ShipStatusUpdateSystem          = 0x1CC9E54;
uintptr_t O_HudManagerUpdate                = 0x1B74334;
uintptr_t O_AmongUsClientUpdate             = 0x1BBBE60;
uintptr_t O_AmongUsClientOnGameJoined       = 0x1BBDBBC;
uintptr_t O_AmongUsClientStartGame          = 0x1BBBE38;

// ── Meetings ──
uintptr_t O_MeetingHudUpdate                = 0x1B86170;
uintptr_t O_MeetingHudVotingComplete        = 0x1B87384;
uintptr_t O_MeetingHudClose                 = 0x1B87238;
uintptr_t O_MeetingHudCastVote              = 0x1B88C58;
uintptr_t O_MeetingHudServerStart           = 0x1B75450;
uintptr_t O_MeetingHudDeserialize           = 0x1B89F3C;

// ── Game logic ──
uintptr_t O_GameManagerCanReportBodies      = 0x1B2E880;
uintptr_t O_GameManagerRpcEndGame           = 0x1B2DD48;
uintptr_t O_GameStartManagerUpdate          = 0x1B3C564;
uintptr_t O_GameDataGetPlayerById           = 0x1EC5A30;

// ── Chat ──
uintptr_t O_ChatControllerSendChat           = 0x1B55BFC;

// ── Roles ──
uintptr_t O_RoleBehaviourGetIsImpostor               = 0x1C8E154;
uintptr_t O_RoleManagerIsImpostorRole                = 0x1C97584;
uintptr_t O_RoleManagerSetRole                       = 0x1C95AA8;

// ── Player ──
uintptr_t O_PlayerControlGetData              = 0x1C42BBC;
uintptr_t O_PlayerControlCanMove              = 0x1C43320;
uintptr_t O_PlayerControlDie                  = 0x1C47524;
uintptr_t O_PlayerControlRevive               = 0x1C47D90;

// ── Cosmetics ──
uintptr_t O_HatManagerGetUnlockedPets         = 0x1E62754;
uintptr_t O_HatManagerGetUnlockedHats         = 0x1E62990;
uintptr_t O_HatManagerAllSkins               = 0x1E61D54;
uintptr_t O_HatManagerAllPets                = 0x1E61D6C;
uintptr_t O_CustomizationDataSetName          = 0x1E1BBE0;
uintptr_t O_CustomizationDataSetHat           = 0x1E1BD84;
uintptr_t O_CustomizationDataSetVisor         = 0x1E1BE9C;
uintptr_t O_CustomizationDataSetSkin          = 0x1E1BE10;
uintptr_t O_CustomizationDataSetPet           = 0x1E1BCF8;
uintptr_t O_CustomizationDataSetNamePlate     = 0x1E1BF28;

// ── Host / Misc ──
uintptr_t O_InnerNetClientAmHost                     = 0x1DABFA8;
uintptr_t O_BanMenuSetVisible                        = 0x1B4DA3C;
uintptr_t O_AccountManagerCanPlayOnline              = 0x1AFD2A8;
uintptr_t O_PingTrackerUpdate                        = 0x1C16E14;
uintptr_t O_SceneManagerInternalSceneLoaded          = 0x44A6874;

// ═══════════════════════════════════════════════════════════════════════════════
//  HOOK REGISTRATION – called once from delayed_init()
// ═══════════════════════════════════════════════════════════════════════════════

static void register_all_hooks(void) {
    // Core Updates
    hook_FixedUpdate();
    hook_SetKillTimer();
    hook_MurderPlayer();
    hook_RpcCompleteTask();
    hook_RpcSetRole();
    hook_RpcSyncSettings();
    hook_PlayerPhysicsFixedUpdate();
    hook_PlayerPhysicsLateUpdate();
    hook_PlayerPhysicsHandleAnimation();
    hook_PlayerPhysicsCoEnterVent();
    hook_PlayerPhysicsCoExitVent();
    hook_ShipStatusFixedUpdate();
    hook_ShipStatusCalculateLightRadius();
    hook_ShipStatusUpdateSystem();
    hook_HudManagerUpdate();
    hook_AmongUsClientUpdate();
    hook_AmongUsClientOnGameJoined();
    hook_AmongUsClientStartGame();

    // Meetings
    hook_MeetingHudUpdate();
    hook_MeetingHudVotingComplete();
    hook_MeetingHudClose();
    hook_MeetingHudCastVote();
    hook_MeetingHudServerStart();
    hook_MeetingHudDeserialize();

    // Game logic
    hook_GameManagerCanReportBodies();
    hook_GameManagerRpcEndGame();
    hook_GameStartManagerUpdate();
    hook_GameDataGetPlayerById();

    // Chat
    hook_ChatControllerSendChat();

    // Roles
    hook_RoleBehaviourGetIsImpostor();
    hook_RoleManagerIsImpostorRole();
    hook_RoleManagerSetRole();

    // Player
    hook_PlayerControlGetData();
    hook_PlayerControlCanMove();
    hook_PlayerControlDie();
    hook_PlayerControlRevive();

    // Cosmetics
    hook_HatManagerGetUnlockedPets();
    hook_HatManagerGetUnlockedHats();
    hook_HatManagerAllSkins();
    hook_HatManagerAllPets();
    hook_CustomizationDataSetName();
    hook_CustomizationDataSetHat();
    hook_CustomizationDataSetVisor();
    hook_CustomizationDataSetSkin();
    hook_CustomizationDataSetPet();
    hook_CustomizationDataSetNamePlate();

    // Host / Misc
    hook_InnerNetClientAmHost();
    hook_BanMenuSetVisible();
    hook_AccountManagerCanPlayOnline();
    hook_PingTrackerUpdate();
    hook_SceneManagerInternalSceneLoaded();

    g_hooksReady = true;

    NSLog(@"[MalumMenu] Hooks installed: %d succeeded, %d failed (out of %llu)",
          g_hookSuccess, g_hookFailed, (unsigned long long)(g_hookSuccess + g_hookFailed));
}

// ═══════════════════════════════════════════════════════════════════════════════
//  DELAYED INIT – waits for UnityFramework, installs hooks, shows UI
// ═══════════════════════════════════════════════════════════════════════════════

static void delayed_init(void) {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        for (int i = 0; i < 30; i++) {
            if (get_unity_base() != 0) break;
            sleep(2);
        }
        if (get_unity_base() == 0) return;
        sleep(10);
        register_all_hooks();
        dispatch_async(dispatch_get_main_queue(), ^{
            [FloatingOverlay present];
        });
    });
}

// ═══════════════════════════════════════════════════════════════════════════════
//  CONSTRUCTOR – runs when dylib is loaded
// ═══════════════════════════════════════════════════════════════════════════════

__attribute__((constructor))
static void initialize() {
    g_toggles.unlockFeatures = true;
    g_toggles.freeCosmetics = true;
    g_toggles.avoidPenalties = true;

    delayed_init();
}
