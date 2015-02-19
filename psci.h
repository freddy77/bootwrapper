#define PSCI_RET_SUCCESS          0
#define PSCI_RET_NOT_IMPL         (-1)
#define PSCI_RET_INVALID          (-2)
#define PSCI_RET_DENIED           (-3)
#define PSCI_RET_ALREADY_ON       (-4)
#define PSCI_RET_ON_PENDING       (-5)
#define PSCI_RET_INTERNAL_FAILURE (-6)
#define PSCI_RET_NOT_PRESENT      (-7)
#define PSCI_RET_DISABLED         (-8)

#define PSCI_STATE_ON_PENDING  2
#define PSCI_STATE_OFF         1
#define PSCI_STATE_ON          0

#define PSCI_VERSION              0x84000000
#define PSCI_CPU_SUSPEND          0x84000001
#define PSCI_CPU_OFF              0x84000002
#define PSCI_CPU_ON               0x84000003
#define PSCI_AFFINITY_INFO        0x84000004
#define PSCI_MIGRATE              0x84000005
#define PSCI_MIGRATE_INFO_TYPE    0x84000006
#define PSCI_MIGRATE_INFO_UP_CPU  0x84000007
#define PSCI_SYSTEM_OFF           0x84000008
#define PSCI_SYSTEM_RESET         0x84000009

int psci(unsigned func, unsigned a1, unsigned a2, unsigned a3);
unsigned long long hip04_cpu_starting(void);
void boot_lock(void);
void boot_unlock(void);
