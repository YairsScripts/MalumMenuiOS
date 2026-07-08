#pragma once
#include <stdint.h>

typedef long dispatch_once_t;
typedef struct dispatch_queue_s *dispatch_queue_t;
typedef void (^dispatch_block_t)(void);
#ifdef __BLOCKS__
void dispatch_async(dispatch_queue_t queue, dispatch_block_t block);
void dispatch_once(dispatch_once_t *predicate, dispatch_block_t block);
dispatch_queue_t dispatch_get_main_queue(void);
#endif
