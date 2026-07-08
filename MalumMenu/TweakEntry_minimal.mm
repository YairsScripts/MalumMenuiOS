#import "FloatingOverlay.h"

__attribute__((constructor))
static void initialize() {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[FloatingOverlay sharedInstance] show];
    });
}
