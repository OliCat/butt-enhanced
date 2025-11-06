#ifndef AES67_PTP_H
#define AES67_PTP_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include <stdbool.h>
#include <time.h>

// Configuration PTP IEEE 1588
typedef struct {
    bool enabled;
    uint64_t master_clock_id;
    uint64_t local_clock_id;
    uint32_t sync_interval_ms;
    uint32_t announce_interval_ms;
    uint32_t delay_req_interval_ms;
    int8_t domain_number;
    uint8_t priority1;
    uint8_t priority2;
    uint8_t clock_class;
    uint8_t clock_accuracy;
    uint16_t offset_scaled_log_variance;
    uint16_t steps_removed;
    uint8_t port_number;
} ptp_config_t;

// État PTP
typedef struct {
    ptp_config_t config;
    bool initialized;
    bool synchronized;
    uint64_t last_sync_time;
    int64_t offset_from_master;
    uint32_t mean_path_delay;
    uint32_t sync_count;
    uint32_t announce_count;
    uint32_t delay_req_count;
} ptp_state_t;

// Fonctions PTP principales
int ptp_init(ptp_state_t* ptp_state);
int ptp_start_sync(ptp_state_t* ptp_state);
int ptp_stop_sync(ptp_state_t* ptp_state);
void ptp_cleanup(ptp_state_t* ptp_state);

// Configuration PTP
int ptp_set_master_clock_id(ptp_state_t* ptp_state, uint64_t master_id);
int ptp_set_domain_number(ptp_state_t* ptp_state, int8_t domain);
int ptp_set_priorities(ptp_state_t* ptp_state, uint8_t priority1, uint8_t priority2);

// Synchronisation temporelle
uint64_t ptp_get_timestamp(ptp_state_t* ptp_state);
int64_t ptp_get_offset_from_master(ptp_state_t* ptp_state);
bool ptp_is_synchronized(ptp_state_t* ptp_state);

// Messages PTP
int ptp_send_sync_message(ptp_state_t* ptp_state);
int ptp_send_announce_message(ptp_state_t* ptp_state);
int ptp_send_delay_req_message(ptp_state_t* ptp_state);
int ptp_process_message(ptp_state_t* ptp_state, const void* message, size_t size);

// Utilitaires
uint64_t ptp_get_system_time_ns(void);
uint64_t ptp_convert_timestamp_to_rtp(uint64_t ptp_timestamp, uint32_t sample_rate);

#ifdef __cplusplus
}
#endif

#endif // AES67_PTP_H 