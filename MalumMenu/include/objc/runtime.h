#pragma once
typedef unsigned short unichar;
typedef signed char BOOL;
#define YES ((BOOL)1)
#define NO ((BOOL)0)
typedef struct objc_class *Class;
typedef struct objc_object {
    Class isa;
} *id;
typedef struct objc_selector *SEL;

#ifndef NULL
#define NULL ((void*)0)
#endif
#ifndef nil
#define nil ((id)0)
#endif

extern Class objc_getClass(const char *name);
extern id objc_msgSend(id self, SEL op, ...);
extern SEL sel_registerName(const char *str);
