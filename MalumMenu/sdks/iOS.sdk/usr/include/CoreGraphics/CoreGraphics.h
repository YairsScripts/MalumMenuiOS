#pragma once
typedef double CGFloat;
struct CGPoint { CGFloat x; CGFloat y; };
struct CGSize { CGFloat width; CGFloat height; };
struct CGRect { CGPoint origin; CGSize size; };
typedef struct CGColorSpace *CGColorSpaceRef;
typedef struct CGColor *CGColorRef;
typedef struct CGContext *CGContextRef;
