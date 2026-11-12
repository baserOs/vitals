#include "CVitalis.h"

#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include <dlfcn.h>
#include <string.h>
#include <sys/types.h>
#include <time.h>

// ===== SMC ===============================================================

#define KERNEL_INDEX_SMC 2
#define SMC_CMD_READ_BYTES 5
#define SMC_CMD_READ_INDEX 8
#define SMC_CMD_READ_KEYINFO 9
// There is deliberately no write command here.

typedef struct {
    char major;
    char minor;
    char build;
    char reserved[1];
    uint16_t release;
} SMCKeyData_vers_t;

typedef struct {
    uint16_t version;
    uint16_t length;
    uint32_t cpuPLimit;
    uint32_t gpuPLimit;
    uint32_t memPLimit;
} SMCKeyData_pLimitData_t;

typedef struct {
    uint32_t dataSize;
    uint32_t dataType;
    char dataAttributes;
} SMCKeyData_keyInfo_t;

typedef struct {
    uint32_t key;
    SMCKeyData_vers_t vers;
    SMCKeyData_pLimitData_t pLimitData;
    SMCKeyData_keyInfo_t keyInfo;
    char result;
    char status;
    char data8;
    uint32_t data32;
    unsigned char bytes[32];
} SMCKeyData_t;

_Static_assert(sizeof(SMCKeyData_t) == 80, "SMCKeyData_t must be 80 bytes");

static uint32_t fourcc(const char *s) {
    return ((uint32_t)(uint8_t)s[0] << 24) | ((uint32_t)(uint8_t)s[1] << 16) |
           ((uint32_t)(uint8_t)s[2] << 8) | (uint32_t)(uint8_t)s[3];
}

static void fourcc_string(uint32_t value, char *out) {
    out[0] = (char)(value >> 24);
    out[1] = (char)(value >> 16);
    out[2] = (char)(value >> 8);
    out[3] = (char)value;
    out[4] = 0;
}

static int smc_call(uint32_t connection, SMCKeyData_t *input, SMCKeyData_t *output) {
    size_t outputSize = sizeof(SMCKeyData_t);
    memset(output, 0, sizeof(SMCKeyData_t));
    kern_return_t result = IOConnectCallStructMethod((io_connect_t)connection, KERNEL_INDEX_SMC,
                                                     input, sizeof(SMCKeyData_t), output, &outputSize);
    if (result != KERN_SUCCESS) return -1;
    return output->result == 0 ? 0 : -1;
}

int vitalis_smc_open(uint32_t *connection) {
    if (!connection) return -1;
    io_iterator_t iterator = 0;
    if (IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleSMC"), &iterator) != KERN_SUCCESS) {
        return -1;
    }
    io_connect_t chosen = 0;
    io_object_t service;
    while ((service = IOIteratorNext(iterator)) != 0) {
        io_connect_t candidate = 0;
        int preferred = 0;
        if (IOServiceOpen(service, mach_task_self(), 0, &candidate) == KERN_SUCCESS && candidate != 0) {
            io_name_t name;
            memset(name, 0, sizeof(name));
            IORegistryEntryGetName(service, name);
            // Apple Silicon exposes the keys through this endpoint.
            preferred = strcmp(name, "AppleSMCKeysEndpoint") == 0;
            if (chosen == 0) {
                chosen = candidate;
            } else if (preferred) {
                IOServiceClose(chosen);
                chosen = candidate;
            } else {
                IOServiceClose(candidate);
            }
        }
        IOObjectRelease(service);
        if (preferred) break;
    }
    IOObjectRelease(iterator);
    if (chosen == 0) return -1;
    *connection = (uint32_t)chosen;
    return 0;
}

void vitalis_smc_close(uint32_t connection) {
    if (connection != 0) IOServiceClose((io_connect_t)connection);
}

int vitalis_smc_key_info(uint32_t connection, const char *key, char *type, uint32_t *size) {
    if (!key || strlen(key) != 4 || !type || !size) return -1;
    SMCKeyData_t input;
    SMCKeyData_t output;
    memset(&input, 0, sizeof(input));
    input.key = fourcc(key);
    input.data8 = SMC_CMD_READ_KEYINFO;
    if (smc_call(connection, &input, &output) != 0) return -1;
    if (output.keyInfo.dataSize == 0 || output.keyInfo.dataSize > 32) return -1;
    fourcc_string(output.keyInfo.dataType, type);
    *size = output.keyInfo.dataSize;
    return 0;
}

int vitalis_smc_read_bytes(uint32_t connection, const char *key, uint32_t size, uint8_t *bytes) {
    if (!key || strlen(key) != 4 || !bytes || size == 0 || size > 32) return -1;
    SMCKeyData_t input;
    SMCKeyData_t output;
    memset(&input, 0, sizeof(input));
    input.key = fourcc(key);
    input.keyInfo.dataSize = size;
    input.data8 = SMC_CMD_READ_BYTES;
    if (smc_call(connection, &input, &output) != 0) return -1;
    memcpy(bytes, output.bytes, size);
    return 0;
}

int vitalis_smc_key_count(uint32_t connection) {
    char type[5];
    uint32_t size = 0;
    uint8_t bytes[32];
    if (vitalis_smc_key_info(connection, "#KEY", type, &size) != 0 || size != 4) return -1;
    if (vitalis_smc_read_bytes(connection, "#KEY", size, bytes) != 0) return -1;
    uint32_t count = ((uint32_t)bytes[0] << 24) | ((uint32_t)bytes[1] << 16) |
                     ((uint32_t)bytes[2] << 8) | (uint32_t)bytes[3];
    if (count > 100000) return -1;
    return (int)count;
}

int vitalis_smc_key_at(uint32_t connection, uint32_t index, char *key) {
    if (!key) return -1;
    SMCKeyData_t input;
    SMCKeyData_t output;
    memset(&input, 0, sizeof(input));
    input.data8 = SMC_CMD_READ_INDEX;
    input.data32 = index;
    if (smc_call(connection, &input, &output) != 0) return -1;
    fourcc_string(output.key, key);
    return 0;
}

// ===== HID temperature sensors ==========================================
//
// IOHIDEventSystemClientCopyServices and IOHIDServiceClientCopyProperty are
// public and come from the headers below. The four functions declared here
// are private; they use the public reference types so nothing clashes.

#include <IOKit/hidsystem/IOHIDEventSystemClient.h>
#include <IOKit/hidsystem/IOHIDServiceClient.h>

extern IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
extern int IOHIDEventSystemClientSetMatching(IOHIDEventSystemClientRef client, CFDictionaryRef match);
extern CFTypeRef IOHIDServiceClientCopyEvent(IOHIDServiceClientRef service, int64_t type, int32_t options, int64_t timestamp);
extern double IOHIDEventGetFloatValue(CFTypeRef event, int32_t field);

#define HID_EVENT_TYPE_TEMPERATURE 15
#define HID_EVENT_FIELD_TEMPERATURE (HID_EVENT_TYPE_TEMPERATURE << 16)
#define HID_MAX_SENSORS 128

static struct {
    char name[96];
    double celsius;
} g_hid[HID_MAX_SENSORS];
static int g_hid_count = 0;
static IOHIDEventSystemClientRef g_hid_client = NULL;

int vitalis_hid_refresh(void) {
    g_hid_count = 0;
    if (!g_hid_client) {
        g_hid_client = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
        if (!g_hid_client) return 0;
        int page = 0xff00;
        int usage = 5;
        CFNumberRef pageNumber = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &page);
        CFNumberRef usageNumber = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &usage);
        const void *keys[2] = { CFSTR("PrimaryUsagePage"), CFSTR("PrimaryUsage") };
        const void *values[2] = { pageNumber, usageNumber };
        CFDictionaryRef match = CFDictionaryCreate(kCFAllocatorDefault, keys, values, 2,
                                                   &kCFTypeDictionaryKeyCallBacks,
                                                   &kCFTypeDictionaryValueCallBacks);
        IOHIDEventSystemClientSetMatching(g_hid_client, match);
        CFRelease(match);
        CFRelease(pageNumber);
        CFRelease(usageNumber);
    }
    CFArrayRef services = IOHIDEventSystemClientCopyServices(g_hid_client);
    if (!services) return 0;
    CFIndex total = CFArrayGetCount(services);
    for (CFIndex i = 0; i < total && g_hid_count < HID_MAX_SENSORS; i++) {
        IOHIDServiceClientRef service = (IOHIDServiceClientRef)CFArrayGetValueAtIndex(services, i);
        if (!service) continue;
        CFTypeRef event = IOHIDServiceClientCopyEvent(service, HID_EVENT_TYPE_TEMPERATURE, 0, 0);
        if (!event) continue;
        double celsius = IOHIDEventGetFloatValue(event, HID_EVENT_FIELD_TEMPERATURE);
        CFRelease(event);

        char *name = g_hid[g_hid_count].name;
        memset(name, 0, sizeof(g_hid[g_hid_count].name));
        CFTypeRef product = IOHIDServiceClientCopyProperty(service, CFSTR("Product"));
        if (product) {
            if (CFGetTypeID(product) == CFStringGetTypeID()) {
                CFStringGetCString((CFStringRef)product, name, sizeof(g_hid[g_hid_count].name), kCFStringEncodingUTF8);
            }
            CFRelease(product);
        }
        if (name[0] == 0) continue;
        g_hid[g_hid_count].celsius = celsius;
        g_hid_count++;
    }
    CFRelease(services);
    return g_hid_count;
}

const char *vitalis_hid_name(int index) {
    if (index < 0 || index >= g_hid_count) return "";
    return g_hid[index].name;
}

double vitalis_hid_celsius(int index) {
    if (index < 0 || index >= g_hid_count) return 0;
    return g_hid[index].celsius;
}

// ===== IOReport energy counters =========================================
//
// libIOReport is private. These are the functions powermetrics uses.

typedef struct IOReportSubscription *IOReportSubscriptionRef;

extern CFDictionaryRef IOReportCopyChannelsInGroup(CFStringRef group, CFStringRef subgroup,
                                                   uint64_t a, uint64_t b, uint64_t c);
extern IOReportSubscriptionRef IOReportCreateSubscription(void *a, CFMutableDictionaryRef desiredChannels,
                                                          CFMutableDictionaryRef *subscribedChannels,
                                                          uint64_t channelID, CFTypeRef b);
extern CFDictionaryRef IOReportCreateSamples(IOReportSubscriptionRef subscription,
                                             CFMutableDictionaryRef subscribedChannels, CFTypeRef a);
extern CFDictionaryRef IOReportCreateSamplesDelta(CFDictionaryRef previous, CFDictionaryRef current, CFTypeRef a);
extern CFStringRef IOReportChannelGetChannelName(CFDictionaryRef channel);
extern CFStringRef IOReportChannelGetUnitLabel(CFDictionaryRef channel);
extern int64_t IOReportSimpleGetIntegerValue(CFDictionaryRef channel, int32_t index);

#define ENERGY_MAX_CHANNELS 256

static struct {
    char channel[96];
    char unit[16];
    double delta;
} g_energy[ENERGY_MAX_CHANNELS];
static int g_energy_count = 0;
static double g_energy_elapsed = 0;
static int g_energy_unavailable = 0;
static IOReportSubscriptionRef g_energy_subscription = NULL;
static CFMutableDictionaryRef g_energy_channels = NULL;
static CFDictionaryRef g_energy_previous = NULL;
static uint64_t g_energy_previous_time = 0;

static void copy_cfstring(CFStringRef string, char *out, size_t size) {
    memset(out, 0, size);
    if (string && CFGetTypeID(string) == CFStringGetTypeID()) {
        CFStringGetCString(string, out, (CFIndex)size, kCFStringEncodingUTF8);
    }
}

int vitalis_energy_refresh(void) {
    g_energy_count = 0;
    g_energy_elapsed = 0;
    if (g_energy_unavailable) return -1;

    if (!g_energy_subscription) {
        CFDictionaryRef found = IOReportCopyChannelsInGroup(CFSTR("Energy Model"), NULL, 0, 0, 0);
        if (!found) {
            g_energy_unavailable = 1;
            return -1;
        }
        g_energy_channels = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, found);
        CFRelease(found);
        CFMutableDictionaryRef subscribed = NULL;
        g_energy_subscription = IOReportCreateSubscription(NULL, g_energy_channels, &subscribed, 0, NULL);
        if (!g_energy_subscription) {
            CFRelease(g_energy_channels);
            g_energy_channels = NULL;
            g_energy_unavailable = 1;
            return -1;
        }
    }

    CFDictionaryRef current = IOReportCreateSamples(g_energy_subscription, g_energy_channels, NULL);
    if (!current) return -1;
    // Uptime does not advance while the Mac sleeps, and neither do the counters.
    uint64_t now = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);

    if (g_energy_previous) {
        g_energy_elapsed = (double)(now - g_energy_previous_time) / 1e9;
        CFDictionaryRef delta = IOReportCreateSamplesDelta(g_energy_previous, current, NULL);
        if (delta) {
            CFTypeRef channels = CFDictionaryGetValue(delta, CFSTR("IOReportChannels"));
            if (channels && CFGetTypeID(channels) == CFArrayGetTypeID()) {
                CFIndex total = CFArrayGetCount((CFArrayRef)channels);
                for (CFIndex i = 0; i < total && g_energy_count < ENERGY_MAX_CHANNELS; i++) {
                    CFTypeRef item = CFArrayGetValueAtIndex((CFArrayRef)channels, i);
                    if (!item || CFGetTypeID(item) != CFDictionaryGetTypeID()) continue;
                    CFDictionaryRef channel = (CFDictionaryRef)item;
                    copy_cfstring(IOReportChannelGetChannelName(channel),
                                  g_energy[g_energy_count].channel, sizeof(g_energy[g_energy_count].channel));
                    copy_cfstring(IOReportChannelGetUnitLabel(channel),
                                  g_energy[g_energy_count].unit, sizeof(g_energy[g_energy_count].unit));
                    g_energy[g_energy_count].delta = (double)IOReportSimpleGetIntegerValue(channel, 0);
                    g_energy_count++;
                }
            }
            CFRelease(delta);
        }
        CFRelease(g_energy_previous);
    }
    g_energy_previous = current;
    g_energy_previous_time = now;
    return g_energy_count;
}

double vitalis_energy_elapsed(void) {
    return g_energy_elapsed;
}

const char *vitalis_energy_channel(int index) {
    if (index < 0 || index >= g_energy_count) return "";
    return g_energy[index].channel;
}

const char *vitalis_energy_unit(int index) {
    if (index < 0 || index >= g_energy_count) return "";
    return g_energy[index].unit;
}

double vitalis_energy_delta(int index) {
    if (index < 0 || index >= g_energy_count) return 0;
    return g_energy[index].delta;
}

// ===== Processes =========================================================
//
// The lookup is not in a public header, so it is found by name at run time.
// If a future system drops it, the function reports -1 and callers fall
// back to the process itself.

int vitalis_responsible_pid(int pid) {
    static pid_t (*lookup)(pid_t) = NULL;
    static int searched = 0;
    if (!searched) {
        lookup = (pid_t (*)(pid_t))dlsym(RTLD_DEFAULT, "responsibility_get_pid_responsible_for_pid");
        searched = 1;
    }
    if (!lookup || pid <= 0) return -1;
    pid_t responsible = lookup((pid_t)pid);
    return responsible > 0 ? (int)responsible : -1;
}
