// ============================================================================
// FloatingOverlay.mm – UIKit overlay: draggable floating icon + menu panel.
// All UI state reads/writes the global `g_toggles` struct.
// ============================================================================

#import "FloatingOverlay.h"
#import "MalumMenu.h"

// ─── Layout constants ───────────────────────────────────────────────────────
static CGFloat const kIconSize     = 48.0f;
static CGFloat const kPanelWidth   = 300.0f;
static CGFloat const kPanelHeight  = 440.0f;
static CGFloat const kCornerRadius = 12.0f;
static CGFloat const kMargin       = 8.0f;

// ─── Colour palette ─────────────────────────────────────────────────────────
#define COLOR(r,g,b,a)  [UIColor colorWithRed:(r)/255.0 green:(g)/255.0 blue:(b)/255.0 alpha:(a)]
#define BG_DARK         COLOR(20,20,30,0.92f)
#define BG_ICON         COLOR(100,80,220,0.70f)
#define TEXT_PRIMARY     [UIColor whiteColor]
#define TEXT_SECONDARY   COLOR(180,180,200,1.0f)
#define ACCENT_GREEN     COLOR(80,220,120,1.0f)
#define ACCENT_RED       COLOR(220,80,80,1.0f)

@interface FloatingOverlay ()

@property (nonatomic, assign) BOOL             isMenuVisible;
@property (nonatomic, assign) CGPoint          dragOffset;

@end

// ─────────────────────────────────────────────────────────────────────────────
//  Implementation
// ─────────────────────────────────────────────────────────────────────────────

@implementation FloatingOverlay

static FloatingOverlay *s_shared = nil;

// ─── Singleton ──────────────────────────────────────────────────────────────
+ (instancetype)sharedInstance {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        s_shared = [[self alloc] initWithFrame:[UIScreen mainScreen].bounds];
    });
    return s_shared;
}

// ─── Present (class method, safe for performSelectorOnMainThread) ────────────
+ (void)present {
    [[self sharedInstance] show];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _isMenuVisible = NO;
        _switches      = [NSMutableDictionary dictionary];

        self.windowLevel = 2100.0;  // above everything (UIWindowLevelAlert + 100)
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = YES;

        // Let touches fall through in transparent areas
    }
    return self;
}

// ─── Hit test – only intercept touches on our UI, pass everything else ──────
- (UIView *)hitTest:(CGPoint)pt withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:pt withEvent:event];
    // Only respond to touches on the floating button or menu panel
    if (hit == self || hit == nil) return nil;  // pass through to Unity
    return hit;
}

// ─── Build UI (call once on main thread) ────────────────────────────────────
- (void)show {
    if (self.floatingBtn) return;              // already built

    self.hidden = NO;

    [self buildFloatingIcon];
    [self buildMenuPanel];
    [self syncUI];
}

// ─── Floating Icon ──────────────────────────────────────────────────────────
- (void)buildFloatingIcon {
    CGFloat x = self.bounds.size.width - kIconSize - 20;
    CGFloat y = self.bounds.size.height * 0.35f;

    self.floatingBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.floatingBtn.frame = CGRectMake(x, y, kIconSize, kIconSize);
    self.floatingBtn.backgroundColor = BG_ICON;
    self.floatingBtn.layer.cornerRadius = kIconSize / 2.0f;
    self.floatingBtn.clipsToBounds = YES;
    self.floatingBtn.layer.borderWidth = 2.0f;
    self.floatingBtn.layer.borderColor = [UIColor whiteColor].CGColor;

    // Hook status badge (top-right corner of button)
    UILabel *badge = [[UILabel alloc] initWithFrame:CGRectMake(kIconSize - 18, -6, 22, 14)];
    badge.text = [NSString stringWithFormat:@"%d/%d", g_hookSuccess, g_hookSuccess + g_hookFailed];
    badge.font = [UIFont boldSystemFontOfSize:8];
    badge.textColor = [UIColor whiteColor];
    badge.backgroundColor = g_hookFailed > 0 ? [UIColor colorWithRed:220/255.0 green:80/255.0 blue:80/255.0 alpha:1] : [UIColor colorWithRed:80/255.0 green:220/255.0 blue:120/255.0 alpha:1];
    badge.textAlignment = NSTextAlignmentCenter;
    badge.layer.cornerRadius = 7;
    badge.clipsToBounds = YES;
    badge.tag = 99;
    [self.floatingBtn addSubview:badge];

    // "M" label
    [self.floatingBtn setTitle:@"M" forState:UIControlStateNormal];
    self.floatingBtn.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    [self.floatingBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];

    // Tap → toggle menu
    [self.floatingBtn addTarget:self action:@selector(onIconTap) forControlEvents:UIControlEventTouchUpInside];

    // Drag gesture
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                          action:@selector(onIconDrag:)];
    [self.floatingBtn addGestureRecognizer:pan];

    [self addSubview:self.floatingBtn];
}

- (void)onIconTap {
    [self toggleMenu];
}

- (void)onIconDrag:(UIPanGestureRecognizer *)g {
    UIView *btn = self.floatingBtn;
    if (g.state == UIGestureRecognizerStateBegan) {
        self.dragOffset = [g locationInView:btn];
    }
    if (g.state == UIGestureRecognizerStateChanged) {
        CGPoint pt = [g locationInView:self];
        CGFloat cx = pt.x - self.dragOffset.x + kIconSize/2;
        CGFloat cy = pt.y - self.dragOffset.y + kIconSize/2;
        cx = MAX(kIconSize/2, MIN(self.bounds.size.width  - kIconSize/2, cx));
        cy = MAX(kIconSize/2, MIN(self.bounds.size.height - kIconSize/2, cy));
        btn.center = CGPointMake(cx, cy);
    }
}

// ─── Menu Panel ─────────────────────────────────────────────────────────────
- (void)buildMenuPanel {
    CGFloat mx = (self.bounds.size.width  - kPanelWidth) / 2.0f;
    CGFloat my = (self.bounds.size.height - kPanelHeight) / 2.0f;

    self.menuPanel = [[UIView alloc] initWithFrame:CGRectMake(mx, my, kPanelWidth, kPanelHeight)];
    self.menuPanel.backgroundColor = BG_DARK;
    self.menuPanel.layer.cornerRadius = kCornerRadius;
    self.menuPanel.clipsToBounds = YES;
    self.menuPanel.hidden = YES;                 // starts hidden

    // Title bar
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, kPanelWidth, 36)];
    title.text = @"  MalumMenu";
    title.font = [UIFont boldSystemFontOfSize:17];
    title.textColor = TEXT_PRIMARY;
    title.backgroundColor = [UIColor clearColor];
    [self.menuPanel addSubview:title];

    // Close button
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    closeBtn.frame = CGRectMake(kPanelWidth - 40, 4, 32, 28);
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor lightGrayColor] forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont systemFontOfSize:16];
    [closeBtn addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
    [self.menuPanel addSubview:closeBtn];

    // Scrollable content
    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 40, kPanelWidth, kPanelHeight - 40)];
    [self.menuPanel addSubview:self.scrollView];

    CGFloat sy = 0;
    sy = [self addSection:@"MOVEMENT"    atY:sy];
    sy = [self addToggle:@"No Clip"      key:@"noClip"        atY:sy];
    sy = [self addToggle:@"Teleport Cursor" key:@"teleportCursor" atY:sy];
    sy = [self addToggle:@"Invert Controls" key:@"invertControls" atY:sy];
    sy = [self addSpacing:6 atY:sy];

    sy = [self addSection:@"COMBAT"      atY:sy];
    sy = [self addToggle:@"No Kill CD"   key:@"noKillCd"      atY:sy];
    sy = [self addToggle:@"Kill Anyone"  key:@"killAnyone"    atY:sy];
    sy = [self addToggle:@"Kill Reach"   key:@"killReach"     atY:sy];
    sy = [self addToggle:@"Complete Tasks" key:@"completeMyTasks" atY:sy];
    sy = [self addSpacing:6 atY:sy];

    sy = [self addSection:@"ROLES"       atY:sy];
    sy = [self addToggle:@"Endless SS Duration" key:@"endlessSsDuration" atY:sy];
    sy = [self addToggle:@"No SS Anim"   key:@"noShapeshiftAnim" atY:sy];
    sy = [self addSpacing:6 atY:sy];

    sy = [self addSection:@"ESP"         atY:sy];
    sy = [self addToggle:@"See Ghosts"   key:@"seeGhosts"     atY:sy];
    sy = [self addToggle:@"See Roles"    key:@"seeRoles"      atY:sy];
    sy = [self addToggle:@"No Shadows"   key:@"noShadows"     atY:sy];
    sy = [self addToggle:@"Reveal Votes" key:@"revealVotes"   atY:sy];
    sy = [self addSpacing:6 atY:sy];

    sy = [self addSection:@"COSMETICS"   atY:sy];
    sy = [self addToggle:@"Free Cosmetics" key:@"freeCosmetics" atY:sy];
    sy = [self addToggle:@"Unlock Features" key:@"unlockFeatures" atY:sy];
    sy = [self addToggle:@"No Penalties" key:@"avoidPenalties" atY:sy];
    sy = [self addSpacing:6 atY:sy];

    sy = [self addSection:@"HOST"        atY:sy];
    sy = [self addToggle:@"Vote Immune"  key:@"voteImmune"    atY:sy];
    sy = [self addToggle:@"Force Start"  key:@"forceStartGame" atY:sy];
    sy = [self addToggle:@"No Game End"  key:@"noGameEnd"     atY:sy];
    sy = [self addToggle:@"No Options Limits" key:@"noOptionsLimits" atY:sy];
    sy = [self addSpacing:6 atY:sy];

    sy = [self addSection:@"CHAT"        atY:sy];
    sy = [self addToggle:@"Longer Messages" key:@"longerMessages" atY:sy];
    sy = [self addToggle:@"Bypass URL Block" key:@"bypassUrlBlock" atY:sy];
    sy = [self addToggle:@"Lower Rate Limits" key:@"lowerRateLimits" atY:sy];
    sy = [self addSpacing:6 atY:sy];

    sy = [self addSection:@"SHIP"        atY:sy];
    sy = [self addToggle:@"Close Meeting" key:@"closeMeeting" atY:sy];
    sy = [self addToggle:@"Skip Meeting" key:@"skipMeeting"   atY:sy];
    sy = [self addToggle:@"Call Meeting" key:@"callMeeting"   atY:sy];
    sy = [self addToggle:@"Unlock Vents" key:@"unlockVents"   atY:sy];
    sy = [self addToggle:@"Walk in Vents" key:@"walkInVents"  atY:sy];
    sy = [self addToggle:@"Auto Open Doors" key:@"autoOpenDoorsOnUse" atY:sy];
    sy += 8;

    self.scrollView.contentSize = CGSizeMake(kPanelWidth - 2*kMargin, sy);

    // Drag handle – reposition the whole panel via pan gesture
    UIPanGestureRecognizer *panelPan = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                               action:@selector(onPanelDrag:)];
    [title addGestureRecognizer:panelPan];
    title.userInteractionEnabled = YES;

    [self addSubview:self.menuPanel];
}

// ─── Helper: section header ─────────────────────────────────────────────────
- (CGFloat)addSection:(NSString *)title atY:(CGFloat)y {
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(kMargin, y, kPanelWidth - 2*kMargin, 26)];
    lbl.text = title;
    lbl.font = [UIFont boldSystemFontOfSize:14];
    lbl.textColor = ACCENT_GREEN;
    [self.scrollView addSubview:lbl];
    return y + 28;
}

// ─── Helper: toggle row ─────────────────────────────────────────────────────
- (CGFloat)addToggle:(NSString *)label key:(NSString *)key atY:(CGFloat)y {
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(kMargin, y, kPanelWidth - 2*kMargin, 36)];

    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, kPanelWidth - 2*kMargin - 60, 36)];
    lbl.text = label;
    lbl.font = [UIFont systemFontOfSize:14];
    lbl.textColor = TEXT_PRIMARY;
    [row addSubview:lbl];

    UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(kPanelWidth - 2*kMargin - 56, 3, 52, 30)];
    sw.onTintColor = ACCENT_GREEN;
    sw.tag = self.switches.count;
    [sw addTarget:self action:@selector(onSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [row addSubview:sw];

    // Store mapping key → switch for syncUI
    [self.switches setObject:sw forKey:key];

    [self.scrollView addSubview:row];
    return y + 38;
}

// ─── Helper: spacer ─────────────────────────────────────────────────────────
- (CGFloat)addSpacing:(CGFloat)h atY:(CGFloat)y {
    return y + h;
}

// ─── Switch event ───────────────────────────────────────────────────────────
- (void)onSwitchChanged:(UISwitch *)sender {
    // Find which key this switch belongs to
    __block NSString *foundKey = nil;
    [self.switches enumerateKeysAndObjectsUsingBlock:^(NSString *key, UISwitch *sw, BOOL *stop) {
        if (sw == sender) { foundKey = key; *stop = YES; }
    }];
    if (!foundKey) return;

    BOOL val = sender.isOn;

    // ── Movement ──
    if      ([foundKey isEqualToString:@"noClip"])            g_toggles.noClip            = val;
    else if ([foundKey isEqualToString:@"teleportCursor"])    g_toggles.teleportCursor    = val;
    else if ([foundKey isEqualToString:@"invertControls"])    g_toggles.invertControls    = val;
    // ── Roles ──
    else if ([foundKey isEqualToString:@"noKillCd"])          g_toggles.noKillCd          = val;
    else if ([foundKey isEqualToString:@"killAnyone"])        g_toggles.killAnyone        = val;
    else if ([foundKey isEqualToString:@"killReach"])         g_toggles.killReach         = val;
    else if ([foundKey isEqualToString:@"completeMyTasks"])   g_toggles.completeMyTasks   = val;
    else if ([foundKey isEqualToString:@"endlessSsDuration"]) g_toggles.endlessSsDuration = val;
    else if ([foundKey isEqualToString:@"noShapeshiftAnim"])  g_toggles.noShapeshiftAnim  = val;
    // ── ESP / Vision ──
    else if ([foundKey isEqualToString:@"seeGhosts"])         g_toggles.seeGhosts         = val;
    else if ([foundKey isEqualToString:@"seeRoles"])          g_toggles.seeRoles          = val;
    else if ([foundKey isEqualToString:@"seeDisguises"])      g_toggles.seeDisguises      = val;
    else if ([foundKey isEqualToString:@"revealVotes"])       g_toggles.revealVotes       = val;
    else if ([foundKey isEqualToString:@"noShadows"])         g_toggles.noShadows         = val;
    // ── Cosmetics ──
    else if ([foundKey isEqualToString:@"freeCosmetics"])     g_toggles.freeCosmetics     = val;
    else if ([foundKey isEqualToString:@"unlockFeatures"])    g_toggles.unlockFeatures    = val;
    else if ([foundKey isEqualToString:@"avoidPenalties"])    g_toggles.avoidPenalties    = val;
    // ── Host ──
    else if ([foundKey isEqualToString:@"voteImmune"])        g_toggles.voteImmune        = val;
    else if ([foundKey isEqualToString:@"forceStartGame"])    g_toggles.forceStartGame    = val;
    else if ([foundKey isEqualToString:@"noGameEnd"])         g_toggles.noGameEnd         = val;
    else if ([foundKey isEqualToString:@"noOptionsLimits"])   g_toggles.noOptionsLimits   = val;
    // ── Chat ──
    else if ([foundKey isEqualToString:@"longerMessages"])    g_toggles.longerMessages    = val;
    else if ([foundKey isEqualToString:@"bypassUrlBlock"])    g_toggles.bypassUrlBlock    = val;
    else if ([foundKey isEqualToString:@"lowerRateLimits"])   g_toggles.lowerRateLimits   = val;
    // ── Ship ──
    else if ([foundKey isEqualToString:@"closeMeeting"])      g_toggles.closeMeeting      = val;
    else if ([foundKey isEqualToString:@"skipMeeting"])       g_toggles.skipMeeting       = val;
    else if ([foundKey isEqualToString:@"callMeeting"])       g_toggles.callMeeting       = val;
    else if ([foundKey isEqualToString:@"unlockVents"])       g_toggles.unlockVents       = val;
    else if ([foundKey isEqualToString:@"walkInVents"])       g_toggles.walkInVents       = val;
    // ── Sabotage ──
    else if ([foundKey isEqualToString:@"autoOpenDoorsOnUse"]) g_toggles.autoOpenDoorsOnUse = val;
}

// ─── Sync UI ← global toggles ───────────────────────────────────────────────
- (void)syncUI {
    [self setSwitch:@"noClip"            on:g_toggles.noClip];
    [self setSwitch:@"teleportCursor"    on:g_toggles.teleportCursor];
    [self setSwitch:@"invertControls"    on:g_toggles.invertControls];
    [self setSwitch:@"noKillCd"          on:g_toggles.noKillCd];
    [self setSwitch:@"killAnyone"        on:g_toggles.killAnyone];
    [self setSwitch:@"killReach"         on:g_toggles.killReach];
    [self setSwitch:@"completeMyTasks"   on:g_toggles.completeMyTasks];
    [self setSwitch:@"endlessSsDuration" on:g_toggles.endlessSsDuration];
    [self setSwitch:@"noShapeshiftAnim"  on:g_toggles.noShapeshiftAnim];
    [self setSwitch:@"seeGhosts"         on:g_toggles.seeGhosts];
    [self setSwitch:@"seeRoles"          on:g_toggles.seeRoles];
    [self setSwitch:@"seeDisguises"      on:g_toggles.seeDisguises];
    [self setSwitch:@"revealVotes"       on:g_toggles.revealVotes];
    [self setSwitch:@"noShadows"         on:g_toggles.noShadows];
    [self setSwitch:@"freeCosmetics"     on:g_toggles.freeCosmetics];
    [self setSwitch:@"unlockFeatures"    on:g_toggles.unlockFeatures];
    [self setSwitch:@"avoidPenalties"    on:g_toggles.avoidPenalties];
    [self setSwitch:@"voteImmune"        on:g_toggles.voteImmune];
    [self setSwitch:@"forceStartGame"    on:g_toggles.forceStartGame];
    [self setSwitch:@"noGameEnd"         on:g_toggles.noGameEnd];
    [self setSwitch:@"noOptionsLimits"   on:g_toggles.noOptionsLimits];
    [self setSwitch:@"longerMessages"    on:g_toggles.longerMessages];
    [self setSwitch:@"bypassUrlBlock"    on:g_toggles.bypassUrlBlock];
    [self setSwitch:@"lowerRateLimits"   on:g_toggles.lowerRateLimits];
    [self setSwitch:@"closeMeeting"      on:g_toggles.closeMeeting];
    [self setSwitch:@"skipMeeting"       on:g_toggles.skipMeeting];
    [self setSwitch:@"callMeeting"       on:g_toggles.callMeeting];
    [self setSwitch:@"unlockVents"       on:g_toggles.unlockVents];
    [self setSwitch:@"walkInVents"       on:g_toggles.walkInVents];
    [self setSwitch:@"autoOpenDoorsOnUse" on:g_toggles.autoOpenDoorsOnUse];
}

- (void)setSwitch:(NSString *)key on:(BOOL)on {
    UISwitch *sw = [self.switches objectForKey:key];
    if (sw) sw.on = on;
}

// ─── Toggle menu visibility ─────────────────────────────────────────────────
- (void)toggleMenu {
    g_showMenu = !g_showMenu;
    self.isMenuVisible = g_showMenu;
    self.menuPanel.hidden = !self.isMenuVisible;
    self.floatingBtn.alpha = self.isMenuVisible ? 0.5f : 1.0f;
}

// ─── Drag menu panel ────────────────────────────────────────────────────────
- (void)onPanelDrag:(UIPanGestureRecognizer *)g {
    static CGPoint startCenter;
    UIView *panel = self.menuPanel;
    if (g.state == UIGestureRecognizerStateBegan) {
        startCenter = panel.center;
    }
    if (g.state == UIGestureRecognizerStateChanged) {
        CGPoint t = [g translationInView:self];
        panel.center = CGPointMake(startCenter.x + t.x, startCenter.y + t.y);
    }
}

@end
