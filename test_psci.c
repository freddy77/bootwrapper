#undef NDEBUG
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

#include "psci.h"

static int expect(int line, int exp, int v)
{
	boot_lock();
	boot_unlock();
	if (v == exp)
		return;
	fprintf(stderr, "Unexpected return in line %d, got %d(%x) expected %d(%x)\n", line, v, v, exp, exp);
	exit(1);
}

void serial_out(char c)
{
	putc(c, stdout);
}

static int lock;

void boot_lock(void)
{
	assert(lock == 0);
	++lock;
}

void boot_unlock(void)
{
	assert(lock == 1);
	--lock;
}

static unsigned fake_mpidr;

unsigned get_mpidr(void)
{
	return fake_mpidr;
}

void v7_flush_dcache_louis(void)
{
}

void v7_flush_dcache_all(void)
{
}

void v7_flush_tlb(void)
{
}

#define expect1(v,a1)          expect(__LINE__, v, psci(a1,0,0,0))
#define expect2(v,a1,a2)       expect(__LINE__, v, psci(a1,a2,0,0))
#define expect3(v,a1,a2,a3)    expect(__LINE__, v, psci(a1,a2,a3,0))
#define expect4(v,a1,a2,a3,a4) expect(__LINE__, v, psci(a1,a2,a3,a4))

int main(void)
{
	unsigned long long res;

	printf("starting\n");
	printf("result: %d\n", expect1(PSCI_RET_NOT_IMPL, 123));

	printf("result: get_version %d\n", expect1(2, PSCI_VERSION));

	/* check wrong cpu get refused */
	printf("result: cpu_on %d\n", expect2(PSCI_RET_INVALID, PSCI_CPU_ON, 0x7));
	printf("result: cpu_on %d\n", expect2(PSCI_RET_INVALID, PSCI_CPU_ON, 0x400));

	printf("result: cpu_on %d\n", expect3(PSCI_RET_SUCCESS, PSCI_CPU_ON, 1, 0x12345678));
	printf("result: cpu_on %d\n", expect3(PSCI_RET_SUCCESS, PSCI_CPU_ON, 0x100, 0x12345678));
	printf("result: cpu_on %d\n", expect4(PSCI_RET_SUCCESS, PSCI_CPU_ON, 0x101, 0xabcdef, 0x87654321));
	printf("result: cpu_on %d\n", expect3(PSCI_RET_ON_PENDING, PSCI_CPU_ON, 0x101, 0xabcdef));
	fake_mpidr = 0x101;
	res = hip04_cpu_starting();
	assert((res & 0xffffffffllu) == 0x87654321);	/* context */
	assert((res >> 32) == 0xabcdef);	/* entry */
	res = hip04_cpu_starting();
	assert(res == 0);
	printf("result: cpu_on %d\n", expect3(PSCI_RET_ALREADY_ON, PSCI_CPU_ON, 0x101, 0x12345678));

	printf("result: %d\n", expect1(PSCI_RET_NOT_IMPL, 0x8400000a));

	printf("result: %d\n", expect1(PSCI_RET_NOT_IMPL, 0x8400000b));

	printf("crash!\n");
	printf("result: %d\n", expect1(PSCI_RET_DENIED, PSCI_SYSTEM_OFF));
	printf("result: %d\n", expect1(PSCI_RET_DENIED, PSCI_SYSTEM_RESET));
	return 0;
}

