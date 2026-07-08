#include <objc/runtime.h>
#include <dispatch/dispatch.h>

typedef double CGFloat;
typedef struct { CGFloat x, y; } CGPoint;
typedef struct { CGFloat width, height; } CGSize;
typedef struct { CGPoint origin; CGSize size; } CGRect;

__attribute__((constructor))
static void init() {
    dispatch_async(dispatch_get_main_queue(), ^{
        id app = ((id(*)(id,SEL))objc_msgSend)(
            (id)objc_getClass("UIApplication"), sel_registerName("sharedApplication"));
        if (!app) return;

        id win = ((id(*)(id,SEL))objc_msgSend)(app, sel_registerName("keyWindow"));
        if (!win)
            win = ((id(*)(id,SEL))objc_msgSend)(
                ((id(*)(id,SEL))objc_msgSend)(app, sel_registerName("windows")),
                sel_registerName("firstObject"));
        if (!win) return;

        CGRect frame = {{50, 150}, {250, 40}};
        id lbl = ((id(*)(id,SEL,CGRect))objc_msgSend)(
            ((id(*)(id,SEL))objc_msgSend)((id)objc_getClass("UILabel"), sel_registerName("alloc")),
            sel_registerName("initWithFrame:"), frame);
        if (!lbl) return;

        id str = ((id(*)(id,SEL,const char*))objc_msgSend)(
            (id)objc_getClass("NSString"), sel_registerName("stringWithUTF8String:"),
            "MalumMenu Loaded!");
        ((void(*)(id,SEL,id))objc_msgSend)(lbl, sel_registerName("setText:"), str);

        ((void(*)(id,SEL,id))objc_msgSend)(lbl, sel_registerName("setTextColor:"),
            ((id(*)(id,SEL))objc_msgSend)((id)objc_getClass("UIColor"), sel_registerName("whiteColor")));

        ((void(*)(id,SEL,id))objc_msgSend)(win, sel_registerName("addSubview:"), lbl);
    });
}
