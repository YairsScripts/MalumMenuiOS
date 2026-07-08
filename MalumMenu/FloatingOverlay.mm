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

// ─── Build UI (call once on main thread) ────────────────────────────────────
- (void)show {
    if (self.floatingBtn) return;              // already built

    [self makeKeyAndVisible];

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
    sy = [self addSection:@"PLAYER"     atY:sy];
    sy = [self addToggle:@"No Cooldown" key:@"noKillCooldown" atY:sy];
    sy = [self addToggle:@"Auto Kill"   key:@"autoKill"      atY:sy];
    sy = [self addToggle:@"Instant Tasks" key:@"instantTasks" atY:sy];
    sy = [self addToggle:@"No Clip"     key:@"noClip"        atY:sy];
    sy = [self addToggle:@"God Mode"    key:@"godMode"       atY:sy];
    sy = [self addSpacing:8 atY:sy];

    sy = [self addSection:@"ROLES"      atY:sy];
    sy = [self addToggle:@"Force Imposter" key:@"forceImposter" atY:sy];
    sy = [self addToggle:@"Show Roles"  key:@"showRoles"     atY:sy];
    sy = [self addSpacing:8 atY:sy];

    sy = [self addSection:@"VISION"     atY:sy];
    sy = [self addToggle:@"Max Vision"  key:@"maxVision"     atY:sy];
    sy = [self addToggle:@"See Ghosts"  key:@"showGhosts"    atY:sy];
    sy = [self addSpacing:8 atY:sy];

    sy = [self addSection:@"COSMETICS"  atY:sy];
    sy = [self addToggle:@"Unlock All"  key:@"unlockAll"     atY:sy];
    sy = [self addToggle:@"Free Purchases" key:@"freePurchases" atY:sy];
    sy = [self addSpacing:8 atY:sy];

    sy = [self addSection:@"HOST"       atY:sy];
    sy = [self addToggle:@"Always Host" key:@"alwaysHost"    atY:sy];
    sy = [self addToggle:@"Force Start" key:@"forceStart"    atY:sy];
    sy = [self addToggle:@"Force End"   key:@"forceEnd"      atY:sy];
    sy = [self addSpacing:8 atY:sy];

    sy = [self addSection:@"CHAT"       atY:sy];
    sy = [self addToggle:@"Bypass Filters" key:@"bypassFilters" atY:sy];
    sy = [self addToggle:@"Spam Chat"  key:@"spamChat"       atY:sy];
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

    // ── Player ──
    if      ([foundKey isEqualToString:@"noKillCooldown"]) g_toggles.noKillCooldown = val;
    else if ([foundKey isEqualToString:@"autoKill"])        g_toggles.autoKill        = val;
    else if ([foundKey isEqualToString:@"instantTasks"])    g_toggles.instantTasks    = val;
    else if ([foundKey isEqualToString:@"noClip"])          g_toggles.noClip          = val;
    else if ([foundKey isEqualToString:@"godMode"])         g_toggles.godMode         = val;
    // ── Roles ──
    else if ([foundKey isEqualToString:@"forceImposter"])   g_toggles.forceImposter   = val;
    else if ([foundKey isEqualToString:@"showRoles"])       g_toggles.showRoles       = val;
    // ── Vision ──
    else if ([foundKey isEqualToString:@"maxVision"])       g_toggles.maxVision       = val;
    else if ([foundKey isEqualToString:@"showGhosts"])      g_toggles.showGhosts      = val;
    // ── Cosmetics ──
    else if ([foundKey isEqualToString:@"unlockAll"])       g_toggles.unlockAll       = val;
    else if ([foundKey isEqualToString:@"freePurchases"])   g_toggles.freePurchases   = val;
    // ── Host ──
    else if ([foundKey isEqualToString:@"alwaysHost"])      g_toggles.alwaysHost      = val;
    else if ([foundKey isEqualToString:@"forceStart"])      g_toggles.forceStart      = val;
    else if ([foundKey isEqualToString:@"forceEnd"])        g_toggles.forceEnd        = val;
    // ── Chat ──
    else if ([foundKey isEqualToString:@"bypassFilters"])   g_toggles.bypassFilters   = val;
    else if ([foundKey isEqualToString:@"spamChat"])        g_toggles.spamChat        = val;
}

// ─── Sync UI ← global toggles ───────────────────────────────────────────────
- (void)syncUI {
    [self setSwitch:@"noKillCooldown" on:g_toggles.noKillCooldown];
    [self setSwitch:@"autoKill"        on:g_toggles.autoKill];
    [self setSwitch:@"instantTasks"    on:g_toggles.instantTasks];
    [self setSwitch:@"noClip"          on:g_toggles.noClip];
    [self setSwitch:@"godMode"         on:g_toggles.godMode];
    [self setSwitch:@"forceImposter"   on:g_toggles.forceImposter];
    [self setSwitch:@"showRoles"       on:g_toggles.showRoles];
    [self setSwitch:@"maxVision"       on:g_toggles.maxVision];
    [self setSwitch:@"showGhosts"      on:g_toggles.showGhosts];
    [self setSwitch:@"unlockAll"       on:g_toggles.unlockAll];
    [self setSwitch:@"freePurchases"   on:g_toggles.freePurchases];
    [self setSwitch:@"alwaysHost"      on:g_toggles.alwaysHost];
    [self setSwitch:@"forceStart"      on:g_toggles.forceStart];
    [self setSwitch:@"forceEnd"        on:g_toggles.forceEnd];
    [self setSwitch:@"bypassFilters"   on:g_toggles.bypassFilters];
    [self setSwitch:@"spamChat"        on:g_toggles.spamChat];
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
