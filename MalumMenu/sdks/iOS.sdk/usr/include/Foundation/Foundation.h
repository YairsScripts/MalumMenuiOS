#pragma once
#import <objc/runtime.h>

typedef unsigned long NSUInteger;
typedef long NSInteger;

// Not in objc/runtime.h on all platforms
#ifndef BOOL
typedef signed char BOOL;
#endif
#ifndef YES
#define YES ((BOOL)1)
#define NO ((BOOL)0)
#endif

@interface NSObject
+ (instancetype)alloc;
- (instancetype)init;
- (void)release;
- (id)autorelease;
- (void)dealloc;
@end

@interface NSString : NSObject
+ (instancetype)stringWithUTF8String:(const char *)nullTerminatedCString;
- (BOOL)isEqualToString:(NSString *)aString;
- (BOOL)isEqual:(id)object;
@property (readonly) NSUInteger length;
@end

@interface NSMutableDictionary : NSObject
+ (instancetype)dictionary;
- (id)objectForKey:(id)aKey;
- (void)setObject:(id)anObject forKey:(id)aKey;
- (void)removeObjectForKey:(id)aKey;
- (void)enumerateKeysAndObjectsUsingBlock:(void (^)(id key, id obj, BOOL *stop))block;
@property (readonly) NSUInteger count;
@end

@interface NSArray : NSObject
@property (readonly) NSUInteger count;
- (id)objectAtIndex:(NSUInteger)index;
@end

// GCD / dispatch stubs
typedef void (^dispatch_block_t)(void);
typedef long dispatch_once_t;
#ifdef __cplusplus
extern "C" {
#endif
void dispatch_once(dispatch_once_t *predicate, dispatch_block_t block);
void dispatch_async(void *queue, dispatch_block_t block);
void *dispatch_get_main_queue(void);
#ifdef __cplusplus
}
#endif
