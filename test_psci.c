#include <stdio.h>
#include <stdlib.h>

#include "psci.h"

static int expect(int line, int exp, int v)
{
	if (v == exp)
		return;
	fprintf(stderr, "Unexpected return in line %d, got %d(%x) expected %d(%x)\n", line, v, v, exp, exp);
	exit(1);
}

#define expect1(v,a1)       expect(__LINE__, v, psci(a1,0,0,0))
#define expect2(v,a1,a2)    expect(__LINE__, v, psci(a1,a2,0,0))
#define expect3(v,a1,a2,a3) expect(__LINE__, v, psci(a1,a2,a3,0))

int main(void)
{
	printf("starting\n");
	printf("result: %d\n", expect1(PSCI_RET_NOT_IMPL, 123));

	printf("result: get_version %d\n", expect1(2, 0x84000000));

	/* check wrong cpu get refused */
	printf("result: cpu_on %d\n", expect2(PSCI_RET_INVALID, 0x84000003, 0x7));
	printf("result: cpu_on %d\n", expect2(PSCI_RET_INVALID, 0x84000003, 0x400));

	printf("result: cpu_on %d\n", expect3(PSCI_RET_SUCCESS, 0x84000003, 1, 0x12345678));
	printf("result: cpu_on %d\n", expect3(PSCI_RET_SUCCESS, 0x84000003, 0x100, 0x12345678));
	printf("result: cpu_on %d\n", expect3(PSCI_RET_SUCCESS, 0x84000003, 0x101, 0x12345678));
	printf("result: cpu_on %d\n", expect3(PSCI_RET_ALREADY_ON, 0x84000003, 0x101, 0x12345678));

	printf("result: %d\n", expect1(PSCI_RET_NOT_IMPL, 0x84000009));

	printf("result: %d\n", expect1(PSCI_RET_NOT_IMPL, 0x8400000a));

	printf("crash!\n");
	printf("result: %d\n", expect1(PSCI_RET_DENIED, 0x84000008));
	return 0;
}

