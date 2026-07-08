#pragma once
#define MSHookFunction(target,replacement,original) do { *(void**)(original) = (void*)(target); } while(0)
