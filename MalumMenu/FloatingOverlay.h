#pragma once
#include <objc/runtime.h>
#include <stdint.h>
#include <stdbool.h>
#include <dispatch/dispatch.h>

#ifndef MIN
#define MIN(a,b) ((a)<(b)?(a):(b))
#endif
#ifndef MAX
#define MAX(a,b) ((a)>(b)?(a):(b))
#endif

typedef double CGFloat;
typedef unsigned long NSUInteger;
typedef long NSInteger;
typedef unsigned int UIControlEvents;
typedef unsigned int UIControlState;
typedef CGFloat UIWindowLevel;
typedef struct CGPoint { CGFloat x, y; } CGPoint;
typedef struct CGSize  { CGFloat width, height; } CGSize;
typedef struct CGRect  { CGPoint origin; CGSize size; } CGRect;
typedef double CFTimeInterval;

__attribute__((unused)) static inline CGRect CGRectMake(CGFloat x, CGFloat y, CGFloat w, CGFloat h) {
    CGRect r; r.origin.x=x; r.origin.y=y; r.size.width=w; r.size.height=h; return r;
}
__attribute__((unused)) static inline CGPoint CGPointMake(CGFloat x, CGFloat y) {
    CGPoint p; p.x=x; p.y=y; return p;
}
__attribute__((unused)) static inline CGSize CGSizeMake(CGFloat w, CGFloat h) {
    CGSize s; s.width=w; s.height=h; return s;
}

enum { UIButtonTypeCustom = 0 };
enum { UIControlStateNormal = 0, UIControlStateHighlighted = 1, UIControlStateDisabled = 2 };
enum {
    UIGestureRecognizerStatePossible, UIGestureRecognizerStateBegan,
    UIGestureRecognizerStateChanged, UIGestureRecognizerStateEnded,
    UIGestureRecognizerStateCancelled, UIGestureRecognizerStateFailed
};
enum {
    UIControlEventTouchDown = 1UL<<0, UIControlEventTouchUpInside = 1UL<<6,
    UIControlEventValueChanged = 1UL<<12
};

@interface NSObject
+ (instancetype)alloc;
- (instancetype)init;
- (void)performSelectorOnMainThread:(SEL)sel withObject:(id)obj waitUntilDone:(BOOL)wait;
@end

@interface NSString : NSObject
+ (instancetype)stringWithUTF8String:(const char *)s;
- (BOOL)isEqualToString:(NSString *)other;
@end

@interface NSMutableDictionary : NSObject
+ (instancetype)dictionary;
- (void)setObject:(id)obj forKey:(id)key;
- (id)objectForKey:(id)key;
- (void)enumerateKeysAndObjectsUsingBlock:(void(^)(id,id,BOOL*))block;
- (NSUInteger)count;
@end

@class UIColor, UIFont, UIGestureRecognizer, UIViewController, UILabel, UIButton, UIEvent;

@interface CALayer : NSObject
@property CGFloat cornerRadius, borderWidth, opacity, shadowOpacity, shadowRadius;
@property (strong) id borderColor, backgroundColor, shadowColor;
@property CGSize shadowOffset;
@property CGRect bounds;
@end

@interface UIResponder : NSObject
@property (strong) CALayer *layer;
@end

@interface UIView : UIResponder
@property CGRect frame, bounds;
@property CGPoint center;
@property CGFloat alpha;
@property (getter=isHidden) BOOL hidden;
@property (getter=isUserInteractionEnabled) BOOL userInteractionEnabled;
@property (getter=isClipsToBounds) BOOL clipsToBounds;
@property NSInteger tag;
- (instancetype)initWithFrame:(CGRect)frame;
- (void)addSubview:(UIView *)view;
- (void)setBackgroundColor:(UIColor *)color;
- (void)addGestureRecognizer:(UIGestureRecognizer *)g;
- (UIView *)hitTest:(CGPoint)pt withEvent:(UIEvent *)event;
@end

@interface UIWindow : UIView
@property UIWindowLevel windowLevel;
- (void)makeKeyAndVisible;
@end

@interface UIColor : NSObject
@property (readonly) id CGColor;
+ (UIColor *)whiteColor;
+ (UIColor *)blackColor;
+ (UIColor *)clearColor;
+ (UIColor *)lightGrayColor;
+ (UIColor *)colorWithWhite:(CGFloat)w alpha:(CGFloat)a;
+ (UIColor *)colorWithRed:(CGFloat)r green:(CGFloat)g blue:(CGFloat)b alpha:(CGFloat)a;
@end

@interface UIFont : NSObject
+ (UIFont *)boldSystemFontOfSize:(CGFloat)s;
+ (UIFont *)systemFontOfSize:(CGFloat)s;
@end

@interface UILabel : UIView
@property (strong) NSString *text;
@property NSInteger textAlignment, numberOfLines;
@property (strong) UIFont *font;
@property (strong) UIColor *textColor;
- (void)sizeToFit;
@end

@interface UIScrollView : UIView
@property CGSize contentSize;
@property BOOL showsHorizontalScrollIndicator, showsVerticalScrollIndicator;
@end

@interface UISwitch : UIView
@property (strong) UIColor *onTintColor;
@property (getter=isOn) BOOL on;
@property NSInteger tag;
- (void)setOn:(BOOL)on animated:(BOOL)animated;
- (void)addTarget:(id)t action:(SEL)a forControlEvents:(UIControlEvents)e;
@end

@interface UIGestureRecognizer : NSObject
- (instancetype)initWithTarget:(id)t action:(SEL)a;
@property CGFloat minimumPressDuration;
@property (readonly) NSInteger state;
@end

@interface UIPanGestureRecognizer : UIGestureRecognizer
- (CGPoint)locationInView:(UIView *)v;
- (CGPoint)translationInView:(UIView *)v;
- (CGPoint)velocityInView:(UIView *)v;
- (void)setTranslation:(CGPoint)t inView:(UIView *)v;
@end

@interface UIButton : UIView
@property (readonly, strong) UILabel *titleLabel;
+ (instancetype)buttonWithType:(NSInteger)t;
- (void)setTitle:(NSString *)t forState:(UIControlState)s;
- (void)setTitleColor:(UIColor *)c forState:(UIControlState)s;
- (void)addTarget:(id)t action:(SEL)a forControlEvents:(UIControlEvents)e;
@end

@interface UIScreen : NSObject
+ (UIScreen *)mainScreen;
- (CGRect)bounds;
@end

@interface UIViewController : UIResponder
@property (strong) UIView *view;
@end

@interface FloatingOverlay : UIWindow
+ (instancetype)sharedInstance;
+ (void)present;  // creates & shows on whatever thread called
- (void)show;
- (void)toggleMenu;
- (void)syncUI;
@property (strong) UIButton *floatingBtn;
@property (strong) UIView *menuPanel;
@property (strong) UIScrollView *scrollView;
@property (strong) NSMutableDictionary *switches;
@end
