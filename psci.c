#include <stdio.h>
#include <stdbool.h>
#include <stdarg.h>

#include "psci.h"

#define FINAL_START (0xe0100000 - 0x10000)

#define CORE_RESET_BIT(x)            (1 << x)
#define NEON_RESET_BIT(x)            (1 << (x + 4))
#define CORE_DEBUG_RESET_BIT(x)      (1 << (x + 9))
#define CLUSTER_L2_RESET_BIT         (1 << 8)
#define CLUSTER_DEBUG_RESET_BIT      (1 << 13)

#define CLUSTER_L2_RESET_STATUS      (1 << 8)
#define CLUSTER_DEBUG_RESET_STATUS   (1 << 13)

#define SC_CPU_RESET_DREQ(x)         (0x524 + (x << 3))    /* unreset */
#define SC_CPU_RESET_STATUS(x)       (0x1520 + (x << 3))

#define FAB_SF_MODE                  0x0c

#define HIP04_MAX_CLUSTERS           4
#define HIP04_MAX_CPUS_PER_CLUSTER   4

#define GICD_SGIR       (0xF00)

#define GICD_SGI_TARGET_OTHERS       (1UL<<GICD_SGI_TARGET_LIST_SHIFT)
#define GICD_SGI_TARGET_LIST_SHIFT   (24)

#define GIC_SGI_EVENT_CHECK 0

static char hip04_cpu_table[HIP04_MAX_CLUSTERS][HIP04_MAX_CPUS_PER_CLUSTER] = {
	{ 0 }
};

#define fabric ((volatile unsigned char*)0xe302a000)
#define sysctrl ((volatile unsigned char*)0xe3e00000)
#define relocation ((volatile unsigned char*)0xe0000100)
#define gic_dbase ((volatile unsigned char*)0xe0c01000)
#define gpio3 ((volatile unsigned char*)0xe4002000)

#ifdef TEST
static unsigned long readl_relaxed(const volatile void *p)
{
	printf("readl_relaxed(%p)\n", p);
	return 123;
}
static void writel_relaxed(unsigned long d, volatile void *p)
{
	printf("writel_relaxed(%lu(%lx), %p)\n", d, d, p);
}
#else
#define readl_relaxed(p) (*((volatile unsigned long*)(p)))
#define writel_relaxed(d, p) do { (*((volatile unsigned long*)(p))) = (d); } while(0)
#endif

#if defined(TEST) || !defined(DEBUG)
#define debug() do {} while(0)
#else
void xprintf(const char *fmt, ...);
#define debug() xprintf("line %x\n", __LINE__)
#endif

static void hip04_set_snoop_filter(unsigned int cluster, unsigned int on)
{
    unsigned long data;

    data = readl_relaxed(fabric + FAB_SF_MODE);
    if ( on )
        data |= 1 << cluster;
    else
        data &= ~(1 << cluster);
    writel_relaxed(data, fabric + FAB_SF_MODE);
    while ( 1 )
    {
        data = readl_relaxed(fabric + FAB_SF_MODE);
        if ( ((data >> cluster) & 1) == on )
            break;
    }
    debug();
}

static inline unsigned get_mpidr(void)
{
#ifdef TEST
	return 0;
#else
	unsigned res;
	__asm__("mrc	p15, 0, %0, c0, c0, 5": "=r"(res) ::);
	return res;
#endif
}

static void hip04_cpu_table_init(void)
{
    static char initialized = 0;
    unsigned cpu, cluster;

    if (initialized)
        return;
    initialized = 1;

    cpu = get_mpidr();
    cluster = (cpu >> 8) & 3;
    cpu &= 3;

    if (hip04_cpu_table[cluster][cpu])
        return;

    hip04_set_snoop_filter(cluster, 1);
    hip04_cpu_table[cluster][cpu] = 1;
}

static bool hip04_cluster_down(unsigned int cluster)
{
    int i;

    for ( i = 0; i < HIP04_MAX_CPUS_PER_CLUSTER; i++ )
        if ( hip04_cpu_table[cluster][i] )
            return false;
    return true;
}

static void hip04_cluster_up(unsigned int cluster)
{
    unsigned long data, mask;

    if ( !hip04_cluster_down(cluster) )
        return;

    data = CLUSTER_L2_RESET_BIT | CLUSTER_DEBUG_RESET_BIT;
    writel_relaxed(data, sysctrl + SC_CPU_RESET_DREQ(cluster));
    do {
        mask = CLUSTER_L2_RESET_STATUS | \
               CLUSTER_DEBUG_RESET_STATUS;
        data = readl_relaxed(sysctrl + \
                     SC_CPU_RESET_STATUS(cluster));
    } while ( data & mask );
    hip04_set_snoop_filter(cluster, 1);
    debug();
}

static inline void cpu_up_send_sgi(int cpu)
{
    __asm__ __volatile__ ("dsb");
    writel_relaxed(GICD_SGI_TARGET_OTHERS|GIC_SGI_EVENT_CHECK, gic_dbase + GICD_SGIR);
}


#ifdef TEST
static inline unsigned get_text_start(void)
{
	return FINAL_START;
}
#else
unsigned get_text_start(void) __attribute__ ((const));
#endif

static int hip04_cpu_up(int cpu, unsigned long entry)
{
    unsigned int cluster;
    unsigned long data;

#ifdef TEST
    printf("hip04_cpu_up %x\n", cpu);
#endif

    debug();

    cluster = (cpu >> 8) & 0xff;
    cpu &= 0xff;

    if (cluster >= HIP04_MAX_CLUSTERS || cpu >= HIP04_MAX_CPUS_PER_CLUSTER)
        return PSCI_RET_INVALID;

    hip04_cpu_table_init();

    if (hip04_cpu_table[cluster][cpu])
        return PSCI_RET_ALREADY_ON;

    debug();
    writel_relaxed(get_text_start(), relocation);
    writel_relaxed(0xa5a5a5a5, relocation + 4);
    writel_relaxed(entry, relocation + 8);
    writel_relaxed(0, relocation + 12);

    hip04_cluster_up(cluster);

    hip04_cpu_table[cluster][cpu] = 1;

    data = CORE_RESET_BIT(cpu) | NEON_RESET_BIT(cpu) | \
           CORE_DEBUG_RESET_BIT(cpu);
    writel_relaxed(data, sysctrl + SC_CPU_RESET_DREQ(cluster));

    cpu_up_send_sgi(cpu);
    debug();
    return PSCI_RET_SUCCESS;
}

#ifdef DEBUG
void serial_out(char c);

void xprintf(const char *fmt, ...)
{
	const char *s = fmt;
	va_list ap;
	unsigned n, i;

	va_start(ap, fmt);

	for (;*s; ++s) {
		if (*s == '%') {
			switch (*++s) {
			case 'x':
				n = va_arg(ap, unsigned);
				for (i = 0; i < 8; ++i) {
					char c = n >> 28;
					serial_out(c + (c < 10 ? '0' : 'a' - 10));
					n <<= 4;
				}
				break;
			default:
				goto error;
			}
			continue;
		}
		serial_out(*s);
		if (*s == 10)
			serial_out(13);
	}
error:
	va_end(ap);
}
#endif

static int hip04_system_reset(void)
{
	writel_relaxed(readl_relaxed(gpio3) & ~0x4000000, gpio3);
#ifndef TEST
	for (;;)
		__asm__ __volatile__ ("wfi");
#endif
	return PSCI_RET_DENIED;
}

/* return status of cluster/cpus */
static int hip04_affinity_info(unsigned long affinity, unsigned long affinity_level)
{
	unsigned cluster, cpu;

	if (affinity_level > 3)
		return PSCI_RET_INVALID;

	/* at least one core is active */
	if (affinity_level == 3 && (affinity >> 24) == 0)
		return PSCI_STATE_ON;
	if (affinity >> 16)
		return PSCI_RET_NOT_PRESENT;
	if (affinity_level == 2)
		return PSCI_STATE_ON;
	cluster = (affinity >> 8) & 0xff;
	if (cluster >= HIP04_MAX_CLUSTERS)
		return PSCI_RET_NOT_PRESENT;
	if (affinity_level == 1) {
		return (hip04_cluster_down(cluster) ?
			PSCI_STATE_OFF : PSCI_STATE_ON);
	}
	cpu = affinity_level & 0xff;
	if (cpu >= HIP04_MAX_CPUS_PER_CLUSTER)
		return PSCI_RET_NOT_PRESENT;

	/* TODO handle powering on */
	return hip04_cpu_table[cluster][cpu] ? PSCI_STATE_ON : PSCI_STATE_OFF;
}

int psci(unsigned func, unsigned a1, unsigned a2, unsigned a3)
{
	switch (func) {
	case PSCI_VERSION:
		return 2;
	case PSCI_CPU_ON:
		return hip04_cpu_up(a1, a2);
	case PSCI_AFFINITY_INFO:
		return hip04_affinity_info(a1, a2);
	case PSCI_SYSTEM_OFF:
		/*
		 * TODO implement correctly, at least should shutdown
		 * all CPUs. For not fall through to reset
		 */
	case PSCI_SYSTEM_RESET:
		return hip04_system_reset();
	}
	return PSCI_RET_NOT_IMPL;
}

