#include <stdint.h>
#include <vx_intrinsics.h>
#include <vx_spawn.h>
#include <vx_print.h>
#include "common.h"

void kernel_body(int task_id, kernel_arg_t *arg) {
	auto A_ptr = reinterpret_cast<int*>(arg->A_addr);
	auto B_ptr = reinterpret_cast<int*>(arg->B_addr);
	auto C_ptr = reinterpret_cast<int*>(arg->C_addr);

	int a = A_ptr[task_id];
	int b = B_ptr[task_id];
	int c = vx_dot8(a, b);

	C_ptr[task_id] = c;
}

int main() {
	kernel_arg_t* arg = (kernel_arg_t*)csr_read(VX_CSR_MSCRATCH);
	vx_spawn_tasks(arg->num_tasks, (vx_spawn_tasks_cb)kernel_body, arg);
	return 0;
}
