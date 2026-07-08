#pragma once
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <QuartzCore/QuartzCore.h>

// Macros
#ifndef MAX
#define MAX(a,b) ({ __typeof__(a) _a = (a); __typeof__(b) _b = (b); _a > _b ? _a : _b; })
#endif
#ifndef MIN
#define MIN(a,b) ({ __typeof__(a) _a = (a); __typeof__(b) _b = (b); _a < _b ? _a : _b; })
#endif

#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type

// Constants
static const NSUInteger UIControlEventTouchUpInside = 1 << 6;
static const NSUInteger UIControlEventValueChanged = 1 << 12;
static const NSInteger UIButtonTypeCustom = 0;
static const NSUInteger UIControlStateNormal = 0;
extern CGFloat const UIWindowLevelAlert;

// Forward declarations
@class UIView;
@class UIColor;
@class UIFont;
@class CALayer;
@class UIGestureRecognizer;

typedef NS_ENUM(NSUInteger, UIGestureRecognizerState) {
    UIGestureRecognizerStatePossible,
    UIGestureRecognizerStateBegan,
    UIGestureRecognizerStateChanged,
    UIGestureRecognizerStateEnded,
    UIGestureRecognizerStateCancelled,
    UIGestureRecognizerStateFailed
};

@interface UIResponder : NSObject
@end

@interface UIColor : NSObject
@property (nonatomic, readonly) CGColorRef CGColor;
+ (UIColor *)colorWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha;
+ (UIColor *)clearColor;
+ (UIColor *)whiteColor;
+ (UIColor *)lightGrayColor;
+ (UIColor *)blackColor;
@end

@interface UIFont : NSObject
+ (UIFont *)systemFontOfSize:(CGFloat)size;
+ (UIFont *)boldSystemFontOfSize:(CGFloat)size;
@end

@interface UIView : UIResponder
@property (nonatomic) CGRect frame;
@property (nonatomic) CGRect bounds;
@property (nonatomic) CGPoint center;
@property (nonatomic) CGFloat alpha;
@property (nonatomic, getter=isHidden) BOOL hidden;
@property (nonatomic, getter=isUserInteractionEnabled) BOOL userInteractionEnabled;
@property (nonatomic, strong) UIColor *backgroundColor;
@property (nonatomic, readonly) CALayer *layer;
@property (nonatomic) BOOL clipsToBounds;
- (void)addSubview:(UIView *)view;
- (void)addGestureRecognizer:(UIGestureRecognizer *)recognizer;
- (instancetype)initWithFrame:(CGRect)frame;
@end

@interface UIWindow : UIView
@property (nonatomic) CGFloat windowLevel;
- (void)makeKeyAndVisible;
@end

@interface UILabel : UIView
@property (nonatomic, copy) NSString *text;
@property (nonatomic, strong) UIFont *font;
@property (nonatomic, strong) UIColor *textColor;
@end

@interface UIButton : UIView
@property (nonatomic, readonly) UILabel *titleLabel;
+ (instancetype)buttonWithType:(NSInteger)buttonType;
- (void)setTitle:(NSString *)title forState:(NSUInteger)state;
- (void)setTitleColor:(UIColor *)color forState:(NSUInteger)state;
- (void)addTarget:(id)target action:(SEL)action forControlEvents:(NSUInteger)events;
@end

@interface UIScrollView : UIView
@property (nonatomic) CGSize contentSize;
@end

@interface UISwitch : UIView
@property (nonatomic, getter=isOn) BOOL on;
@property (nonatomic, strong) UIColor *onTintColor;
@property (nonatomic) NSInteger tag;
- (void)addTarget:(id)target action:(SEL)action forControlEvents:(NSUInteger)events;
@end

@interface UIGestureRecognizer : NSObject
@property (nonatomic, readonly) UIGestureRecognizerState state;
- (instancetype)initWithTarget:(id)target action:(SEL)action;
- (CGPoint)locationInView:(UIView *)view;
@end

@interface UIPanGestureRecognizer : UIGestureRecognizer
- (CGPoint)translationInView:(UIView *)view;
@end

@interface UIScreen : NSObject
@property (nonatomic, readonly) CGRect bounds;
+ (UIScreen *)mainScreen;
@end

// Inline helpers
__attribute__((unused)) static inline CGRect CGRectMake(CGFloat x, CGFloat y, CGFloat width, CGFloat height) {
    CGRect r; r.origin.x = x; r.origin.y = y; r.size.width = width; r.size.height = height; return r;
}
__attribute__((unused)) static inline CGPoint CGPointMake(CGFloat x, CGFloat y) {
    CGPoint p; p.x = x; p.y = y; return p;
}
__attribute__((unused)) static inline CGSize CGSizeMake(CGFloat width, CGFloat height) {
    CGSize s; s.width = width; s.height = height; return s;
}
