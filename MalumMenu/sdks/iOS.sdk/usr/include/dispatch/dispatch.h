#pragma once
#include <stdint.h>

#define DISPATCH_ONCE_INLINE
typedef intptr_t dispatch_once_t;
void dispatch_once(dispatch_once_t *predicate, dispatch_block_t block);

typedef void *dispatch_queue_t;
void dispatch_async(dispatch_queue_t queue, dispatch_block_t block);
dispatch_queue_t dispatch_get_main_queue(void);
