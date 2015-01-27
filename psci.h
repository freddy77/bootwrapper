#define PSCI_RET_SUCCESS        0
#define PSCI_RET_NOT_IMPL       (-1)
#define PSCI_RET_INVALID        (-2)
#define PSCI_RET_DENIED         (-3)
#define PSCI_RET_ALREADY_ON     (-4)

#define PSCI_VERSION    0x84000000
#define PSCI_CPU_ON     0x84000003
#define PSCI_SYSTEM_OFF 0x84000008

int psci(unsigned func, unsigned a1, unsigned a2, unsigned a3);
