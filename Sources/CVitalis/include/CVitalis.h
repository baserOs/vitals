#ifndef CVITALIS_H
#define CVITALIS_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// All functions here only read. None of them writes to the hardware.
// The HID and energy functions keep static state and are not thread safe:
// call them from one serial queue.

// ---- SMC -------------------------------------------------------------

/// Opens the AppleSMC service and stores the connection. Returns 0 on success.
int vitalis_smc_open(uint32_t *connection);
void vitalis_smc_close(uint32_t connection);

/// Number of SMC keys, or -1 on failure.
int vitalis_smc_key_count(uint32_t connection);

/// Writes the key at `index` into `key` (5 bytes, NUL-terminated). Returns 0 on success.
int vitalis_smc_key_at(uint32_t connection, uint32_t index, char *key);

/// Looks up a 4-character key. Writes its type (5 bytes, NUL-terminated) and
/// its data size in bytes (1...32). Returns 0 on success.
int vitalis_smc_key_info(uint32_t connection, const char *key, char *type, uint32_t *size);

/// Reads `size` bytes of a key's value into `bytes` (room for 32). Returns 0 on success.
int vitalis_smc_read_bytes(uint32_t connection, const char *key, uint32_t size, uint8_t *bytes);

// ---- HID temperature sensors ------------------------------------------

/// Reads every HID temperature sensor. Returns how many were read.
int vitalis_hid_refresh(void);
const char *vitalis_hid_name(int index);
double vitalis_hid_celsius(int index);

// ---- IOReport energy counters -----------------------------------------

/// Takes an energy sample and computes the change since the previous call.
/// Returns the number of channels with a change, 0 on the first call, and
/// -1 if IOReport is not available.
int vitalis_energy_refresh(void);
/// Seconds between the two samples behind the latest refresh.
double vitalis_energy_elapsed(void);
const char *vitalis_energy_channel(int index);
const char *vitalis_energy_unit(int index);
double vitalis_energy_delta(int index);

// ---- Processes --------------------------------------------------------

/// The pid of the app that a process works for, as macOS itself attributes
/// it (a browser tab's process answers to the browser). Returns the same
/// pid when the process answers for itself, and -1 when the system does
/// not offer the lookup.
int vitalis_responsible_pid(int pid);

#ifdef __cplusplus
}
#endif

#endif
