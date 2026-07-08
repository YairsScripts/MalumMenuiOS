#pragma once
#import <CoreGraphics/CoreGraphics.h>
#include <stdint.h>

@interface CALayer : NSObject
@property CGFloat cornerRadius;
@property CGFloat borderWidth;
@property CGColorRef borderColor;
@property CGColorRef backgroundColor;
@property BOOL masksToBounds;
@property BOOL clipsToBounds;
@end
