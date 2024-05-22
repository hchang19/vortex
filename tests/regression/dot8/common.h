#ifndef _COMMON_H_
#define _COMMON_H_

typedef struct {
  uint32_t num_tasks;
  uint64_t A_addr;
  uint64_t B_addr;
  uint64_t C_addr;
} kernel_arg_t;

#endif
