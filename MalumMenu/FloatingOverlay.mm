#import "FloatingOverlay.h"
#import "MalumMenu.h"

static CGFloat const kIconSize     = 52.0f;
static CGFloat const kPanelWidth   = 310.0f;
static CGFloat const kPanelHeight  = 460.0f;
static CGFloat const kCornerRadius = 16.0f;
static CGFloat const kMargin       = 10.0f;

#define COLOR(r,g,b,a)  [UIColor colorWithRed:(r)/255.0 green:(g)/255.0 blue:(b)/255.0 alpha:(a)]
#define ACCENT           COLOR(100,80,220,1.0f)
#define ACCENT_GREEN     COLOR(80,220,120,1.0f)
#define ACCENT_RED       COLOR(220,80,80,1.0f)
#define TEXT_PRIMARY     [UIColor whiteColor]
#define TEXT_SECONDARY   COLOR(200,200,215,1.0f)
#define BG_DARK          COLOR(22,22,34,0.92f)

@interface FloatingOverlay ()
@property (nonatomic, assign) BOOL    isMenuVisible;
@property (nonatomic, assign) CGPoint dragOffset;
@property (nonatomic, strong) UIView  *blurView;
@end

@implementation FloatingOverlay

static FloatingOverlay *s_shared = nil;

+ (instancetype)sharedInstance {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        s_shared = [[self alloc] initWithFrame:[UIScreen mainScreen].bounds];
    });
    return s_shared;
}

+ (void)present {
    [[self sharedInstance] show];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _isMenuVisible = NO;
        _switches      = [NSMutableDictionary dictionary];
        self.windowLevel = 2100.0;
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = YES;
    }
    return self;
}

- (UIView *)hitTest:(CGPoint)pt withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:pt withEvent:event];
    if (hit == self || hit == nil) return nil;
    return hit;
}

- (void)show {
    if (self.floatingBtn) return;
    self.hidden = NO;
    [self buildFloatingIcon];
    [self buildBlurBackground];
    [self buildMenuPanel];
    [self syncUI];
}

- (void)buildFloatingIcon {
    CGFloat x = self.bounds.size.width - kIconSize - 16;
    CGFloat y = self.bounds.size.height * 0.35f;

    self.floatingBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.floatingBtn.frame = CGRectMake(x, y, kIconSize, kIconSize);
    self.floatingBtn.backgroundColor = ACCENT;
    self.floatingBtn.layer.cornerRadius = kIconSize / 2.0f;
    self.floatingBtn.clipsToBounds = YES;
    self.floatingBtn.layer.borderWidth = 2.0f;
    self.floatingBtn.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.5].CGColor;
    self.floatingBtn.layer.shadowColor = ACCENT.CGColor;
    self.floatingBtn.layer.shadowOpacity = 0.5f;
    self.floatingBtn.layer.shadowRadius = 8.0f;
    self.floatingBtn.layer.shadowOffset = CGSizeZero;

    [self.floatingBtn setTitle:@"K" forState:UIControlStateNormal];
    self.floatingBtn.titleLabel.font = [UIFont boldSystemFontOfSize:22];
    [self.floatingBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];

    [self.floatingBtn addTarget:self action:@selector(onIconTap) forControlEvents:UIControlEventTouchUpInside];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                          action:@selector(onIconDrag:)];
    [self.floatingBtn addGestureRecognizer:pan];

    self.floatingBtn.transform = CGAffineTransformMakeScale(0.1, 0.1);
    [UIView animateWithDuration:0.6 delay:0 usingSpringWithDamping:0.5 initialSpringVelocity:0.8 options:0 animations:^{
        self.floatingBtn.transform = CGAffineTransformIdentity;
    } completion:nil];

    [self addSubview:self.floatingBtn];
}

- (void)onIconTap {
    [self toggleMenu];
}

- (void)onIconDrag:(UIPanGestureRecognizer *)g {
    UIView *btn = self.floatingBtn;
    if (g.state == UIGestureRecognizerStateBegan) {
        self.dragOffset = [g locationInView:btn];
        [UIView animateWithDuration:0.2 animations:^{
            btn.transform = CGAffineTransformMakeScale(1.15, 1.15);
        }];
    }
    if (g.state == UIGestureRecognizerStateChanged) {
        CGPoint pt = [g locationInView:self];
        CGFloat cx = pt.x - self.dragOffset.x + kIconSize/2;
        CGFloat cy = pt.y - self.dragOffset.y + kIconSize/2;
        cx = MAX(kIconSize/2, MIN(self.bounds.size.width  - kIconSize/2, cx));
        cy = MAX(kIconSize/2, MIN(self.bounds.size.height - kIconSize/2, cy));
        btn.center = CGPointMake(cx, cy);
    }
    if (g.state == UIGestureRecognizerStateEnded) {
        [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.6 initialSpringVelocity:0 options:0 animations:^{
            btn.transform = CGAffineTransformIdentity;
        } completion:nil];
    }
}

- (void)buildBlurBackground {
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *vev = [[UIVisualEffectView alloc] initWithEffect:blur];
    vev.frame = self.bounds;
    vev.alpha = 0;
    vev.userInteractionEnabled = NO;
    self.blurView = vev;
    [self addSubview:vev];
}

- (void)buildMenuPanel {
    CGFloat mx = (self.bounds.size.width  - kPanelWidth) / 2.0f;
    CGFloat my = (self.bounds.size.height - kPanelHeight) / 2.0f;

    self.menuPanel = [[UIView alloc] initWithFrame:CGRectMake(mx, my, kPanelWidth, kPanelHeight)];
    self.menuPanel.backgroundColor = BG_DARK;
    self.menuPanel.layer.cornerRadius = kCornerRadius;
    self.menuPanel.clipsToBounds = YES;
    self.menuPanel.alpha = 0;
    self.menuPanel.transform = CGAffineTransformMakeTranslation(0, 30);
    self.menuPanel.hidden = YES;

    self.menuPanel.layer.shadowColor = [UIColor blackColor].CGColor;
    self.menuPanel.layer.shadowOpacity = 0.4f;
    self.menuPanel.layer.shadowRadius = 20.0f;
    self.menuPanel.layer.shadowOffset = CGSizeMake(0, 8);

    // Accent bar at top
    UIView *accentBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kPanelWidth, 3)];
    accentBar.backgroundColor = ACCENT;
    [self.menuPanel addSubview:accentBar];

    // Title
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(14, 10, 180, 30)];
    title.text = @"Kartex";
    title.font = [UIFont boldSystemFontOfSize:20];
    title.textColor = TEXT_PRIMARY;
    [self.menuPanel addSubview:title];

    // Subtitle
    UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(14, 32, 180, 14)];
    sub.text = @"cheat menu";
    sub.font = [UIFont systemFontOfSize:11];
    sub.textColor = TEXT_SECONDARY;
    [self.menuPanel addSubview:sub];

    // Close button
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    closeBtn.frame = CGRectMake(kPanelWidth - 42, 10, 32, 30);
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    [closeBtn setTitleColor:TEXT_SECONDARY forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont systemFontOfSize:18];
    closeBtn.alpha = 0.7f;
    [closeBtn addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
    [self.menuPanel addSubview:closeBtn];

    // Separator
    UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(14, 52, kPanelWidth - 28, 1)];
    sep.backgroundColor = COLOR(255,255,255,0.08f);
    [self.menuPanel addSubview:sep];

    // Scroll
    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 56, kPanelWidth, kPanelHeight - 56)];
    self.scrollView.showsVerticalScrollIndicator = NO;
    [self.menuPanel addSubview:self.scrollView];

    CGFloat sy = 0;
    sy = [self addSection:@"MOVEMENT"    atY:sy];
    sy = [self addToggle:@"No Clip"      key:@"noClip"        atY:sy];
    sy = [self addToggle:@"Teleport"     key:@"teleportCursor" atY:sy];
    sy = [self addToggle:@"Invert"       key:@"invertControls" atY:sy];
    sy = [self addSpacing:8 atY:sy];

    sy = [self addSection:@"COMBAT"      atY:sy];
    sy = [self addToggle:@"No Kill CD"   key:@"noKillCd"      atY:sy];
    sy = [self addToggle:@"Kill Anyone"  key:@"killAnyone"    atY:sy];
    sy = [self addToggle:@"Kill Reach"   key:@"killReach"     atY:sy];
    sy = [self addToggle:@"Auto Tasks"   key:@"completeMyTasks" atY:sy];
    sy = [self addSpacing:8 atY:sy];

    sy = [self addSection:@"ROLES"       atY:sy];
    sy = [self addToggle:@"Inf SS"       key:@"endlessSsDuration" atY:sy];
    sy = [self addToggle:@"No SS Anim"   key:@"noShapeshiftAnim" atY:sy];
    sy = [self addSpacing:8 atY:sy];

    sy = [self addSection:@"ESP"         atY:sy];
    sy = [self addToggle:@"See Ghosts"   key:@"seeGhosts"     atY:sy];
    sy = [self addToggle:@"See Roles"    key:@"seeRoles"      atY:sy];
    sy = [self addToggle:@"No Shadows"   key:@"noShadows"     atY:sy];
    sy = [self addToggle:@"Reveal Votes" key:@"revealVotes"   atY:sy];
    sy = [self addSpacing:8 atY:sy];

    sy = [self addSection:@"COSMETICS"   atY:sy];
    sy = [self addToggle:@"Free Cos."    key:@"freeCosmetics" atY:sy];
    sy = [self addToggle:@"Unlock All"   key:@"unlockFeatures" atY:sy];
    sy = [self addToggle:@"No Penalty"   key:@"avoidPenalties" atY:sy];
    sy = [self addSpacing:8 atY:sy];

    sy = [self addSection:@"HOST"        atY:sy];
    sy = [self addToggle:@"Vote Immune"  key:@"voteImmune"    atY:sy];
    sy = [self addToggle:@"Force Start"  key:@"forceStartGame" atY:sy];
    sy = [self addToggle:@"No Game End"  key:@"noGameEnd"     atY:sy];
    sy = [self addToggle:@"No Limits"    key:@"noOptionsLimits" atY:sy];
    sy = [self addSpacing:8 atY:sy];

    sy = [self addSection:@"CHAT"        atY:sy];
    sy = [self addToggle:@"Long Msg"     key:@"longerMessages" atY:sy];
    sy = [self addToggle:@"Unblock URLs" key:@"bypassUrlBlock" atY:sy];
    sy = [self addToggle:@"No Cooldown"  key:@"lowerRateLimits" atY:sy];
    sy = [self addSpacing:8 atY:sy];

    sy = [self addSection:@"SHIP"        atY:sy];
    sy = [self addToggle:@"Close Meet"   key:@"closeMeeting"  atY:sy];
    sy = [self addToggle:@"Skip Meet"    key:@"skipMeeting"   atY:sy];
    sy = [self addToggle:@"Call Meet"    key:@"callMeeting"   atY:sy];
    sy = [self addToggle:@"Unlock Vents" key:@"unlockVents"   atY:sy];
    sy = [self addToggle:@"Walk Vents"   key:@"walkInVents"   atY:sy];
    sy = [self addToggle:@"Auto Doors"   key:@"autoOpenDoorsOnUse" atY:sy];
    sy += 8;

    self.scrollView.contentSize = CGSizeMake(kPanelWidth - 2*kMargin, sy);

    UIPanGestureRecognizer *panelPan = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                                action:@selector(onPanelDrag:)];
    [title addGestureRecognizer:panelPan];
    title.userInteractionEnabled = YES;

    [self addSubview:self.menuPanel];
}

- (CGFloat)addSection:(NSString *)title atY:(CGFloat)y {
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(kMargin, y, kPanelWidth - 2*kMargin, 26)];

    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(4, 0, 200, 26)];
    lbl.text = title;
    lbl.font = [UIFont boldSystemFontOfSize:12];
    lbl.textColor = ACCENT;
    [container addSubview:lbl];

    [self.scrollView addSubview:container];
    return y + 30;
}

- (CGFloat)addToggle:(NSString *)label key:(NSString *)key atY:(CGFloat)y {
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(kMargin, y, kPanelWidth - 2*kMargin, 38)];

    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(4, 0, kPanelWidth - 2*kMargin - 70, 38)];
    lbl.text = label;
    lbl.font = [UIFont systemFontOfSize:14];
    lbl.textColor = TEXT_PRIMARY;
    [row addSubview:lbl];

    UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(kPanelWidth - 2*kMargin - 60, 4, 52, 30)];
    sw.onTintColor = ACCENT;
    sw.tag = self.switches.count;
    [sw addTarget:self action:@selector(onSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [row addSubview:sw];

    [self.switches setObject:sw forKey:key];
    [self.scrollView addSubview:row];
    return y + 40;
}

- (CGFloat)addSpacing:(CGFloat)h atY:(CGFloat)y {
    return y + h;
}

- (void)onSwitchChanged:(UISwitch *)sender {
    __block NSString *foundKey = nil;
    [self.switches enumerateKeysAndObjectsUsingBlock:^(NSString *key, UISwitch *sw, BOOL *stop) {
        if (sw == sender) { foundKey = key; *stop = YES; }
    }];
    if (!foundKey) return;
    BOOL val = sender.isOn;
    if      ([foundKey isEqualToString:@"noClip"])            g_toggles.noClip            = val;
    else if ([foundKey isEqualToString:@"teleportCursor"])    g_toggles.teleportCursor    = val;
    else if ([foundKey isEqualToString:@"invertControls"])    g_toggles.invertControls    = val;
    else if ([foundKey isEqualToString:@"noKillCd"])          g_toggles.noKillCd          = val;
    else if ([foundKey isEqualToString:@"killAnyone"])        g_toggles.killAnyone        = val;
    else if ([foundKey isEqualToString:@"killReach"])         g_toggles.killReach         = val;
    else if ([foundKey isEqualToString:@"completeMyTasks"])   g_toggles.completeMyTasks   = val;
    else if ([foundKey isEqualToString:@"endlessSsDuration"]) g_toggles.endlessSsDuration = val;
    else if ([foundKey isEqualToString:@"noShapeshiftAnim"])  g_toggles.noShapeshiftAnim  = val;
    else if ([foundKey isEqualToString:@"seeGhosts"])         g_toggles.seeGhosts         = val;
    else if ([foundKey isEqualToString:@"seeRoles"])          g_toggles.seeRoles          = val;
    else if ([foundKey isEqualToString:@"seeDisguises"])      g_toggles.seeDisguises      = val;
    else if ([foundKey isEqualToString:@"revealVotes"])       g_toggles.revealVotes       = val;
    else if ([foundKey isEqualToString:@"noShadows"])         g_toggles.noShadows         = val;
    else if ([foundKey isEqualToString:@"freeCosmetics"])     g_toggles.freeCosmetics     = val;
    else if ([foundKey isEqualToString:@"unlockFeatures"])    g_toggles.unlockFeatures    = val;
    else if ([foundKey isEqualToString:@"avoidPenalties"])    g_toggles.avoidPenalties    = val;
    else if ([foundKey isEqualToString:@"voteImmune"])        g_toggles.voteImmune        = val;
    else if ([foundKey isEqualToString:@"forceStartGame"])    g_toggles.forceStartGame    = val;
    else if ([foundKey isEqualToString:@"noGameEnd"])         g_toggles.noGameEnd         = val;
    else if ([foundKey isEqualToString:@"noOptionsLimits"])   g_toggles.noOptionsLimits   = val;
    else if ([foundKey isEqualToString:@"longerMessages"])    g_toggles.longerMessages    = val;
    else if ([foundKey isEqualToString:@"bypassUrlBlock"])    g_toggles.bypassUrlBlock    = val;
    else if ([foundKey isEqualToString:@"lowerRateLimits"])   g_toggles.lowerRateLimits   = val;
    else if ([foundKey isEqualToString:@"closeMeeting"])      g_toggles.closeMeeting      = val;
    else if ([foundKey isEqualToString:@"skipMeeting"])       g_toggles.skipMeeting       = val;
    else if ([foundKey isEqualToString:@"callMeeting"])       g_toggles.callMeeting       = val;
    else if ([foundKey isEqualToString:@"unlockVents"])       g_toggles.unlockVents       = val;
    else if ([foundKey isEqualToString:@"walkInVents"])       g_toggles.walkInVents       = val;
    else if ([foundKey isEqualToString:@"autoOpenDoorsOnUse"]) g_toggles.autoOpenDoorsOnUse = val;
}

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
    if (sw) [sw setOn:on animated:YES];
}

- (void)toggleMenu {
    g_showMenu = !g_showMenu;
    self.isMenuVisible = g_showMenu;

    if (self.isMenuVisible) {
        self.menuPanel.hidden = NO;
        self.menuPanel.alpha = 0;
        self.menuPanel.transform = CGAffineTransformMakeTranslation(0, 40);
        self.blurView.alpha = 0;

        [UIView animateWithDuration:0.5 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.8 options:0 animations:^{
            self.menuPanel.alpha = 1;
            self.menuPanel.transform = CGAffineTransformIdentity;
            self.blurView.alpha = 1;
            self.floatingBtn.alpha = 0.4f;
        } completion:nil];
    } else {
        [UIView animateWithDuration:0.2 animations:^{
            self.menuPanel.alpha = 0;
            self.menuPanel.transform = CGAffineTransformMakeTranslation(0, 20);
            self.blurView.alpha = 0;
            self.floatingBtn.alpha = 1;
        } completion:^(BOOL finished) {
            self.menuPanel.hidden = YES;
        }];
    }
}

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