//
//  SystemHardware.m
//  REFLEC BEAT plus
//
//  Reconstructed from Ghidra project rb458, program rb458 (class SystemHardware). Verified against
//  the arm64 disassembly (the sysctlbyname call, the model-string table, and the retaining setter
//  are obscured by the decompiler).
//

#import "SystemHardware.h"

#include <stdlib.h>
#include <string.h>
#include <sys/sysctl.h>

// The sysctl name that reports the device's machine model, for example @c iPhone3,1.
static const char *const kMachineSysctlName = "hw.machine";

// The sentinel hardware type stored by @c -init before the model has been resolved.
static const int kHardwareTypeUnresolved = 15;

/**
 * The known @c hw.machine model strings, indexed by @c SystemHardwareType. A device whose model is
 * absent here is classified as @c SystemHardwareTypeUnknown.
 * @ghidraAddress 0x358e58
 */
static const char *const kHardwareModelTable[] = {
    "iPhone1,1", "iPhone1,2", "iPhone2,1", "iPhone3,1", "iPhone3,2", "iPod1,1", "iPod2,1",
    "iPod3,1",   "iPod4,1",   "iPad1,1",   "iPad2,1",   "iPad2,2",   "iPad2,3", "i386",
};

// The number of known models in @c kHardwareModelTable.
static const NSUInteger kHardwareModelCount =
    sizeof(kHardwareModelTable) / sizeof(kHardwareModelTable[0]);

@implementation SystemHardware {
    // The resolved hardware type, or @c kHardwareTypeUnresolved until @c -initHardware runs.
    int m_HardwareType;
}

// The shared singleton instance.
static SystemHardware *g_sharedInstance = nil;

#pragma mark Singleton

+ (instancetype)getInstance {
    /** @ghidraAddress 0x18b14 */
    if (!g_sharedInstance) {
        g_sharedInstance = [[SystemHardware alloc] init];
    }
    return g_sharedInstance;
}

- (instancetype)init {
    /** @ghidraAddress 0x18a98 */
    self = [super init];
    if (self) {
        m_HardwareType = kHardwareTypeUnresolved;
    }
    return self;
}

#pragma mark Resolution

- (void)initHardware {
    /** @ghidraAddress 0x18b6c */
    if (m_HardwareType != kHardwareTypeUnresolved) {
        return;
    }
    size_t length = 0;
    sysctlbyname(kMachineSysctlName, NULL, &length, NULL, 0);
    char *model = malloc(length);
    sysctlbyname(kMachineSysctlName, model, &length, NULL, 0);
    self.hardwareName = nil;
    self.hardwareName = [[NSString alloc] initWithCString:model encoding:NSUTF8StringEncoding];
    for (NSUInteger index = 0; index < kHardwareModelCount; ++index) {
        if (strcmp(kHardwareModelTable[index], model) == 0) {
            m_HardwareType = (int)index;
            free(model);
            return;
        }
    }
    free(model);
    m_HardwareType = SystemHardwareTypeUnknown;
}

- (SystemHardwareType)getHardwareType {
    /** @ghidraAddress 0x18cb0 */
    if (m_HardwareType == kHardwareTypeUnresolved) {
        [self initHardware];
    }
    return (SystemHardwareType)m_HardwareType;
}

- (NSString *)getHardwareName {
    /** @ghidraAddress 0x18cf4 */
    if (m_HardwareType == kHardwareTypeUnresolved) {
        [self initHardware];
    }
    return self.hardwareName;
}

@end
