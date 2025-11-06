#ifndef AES67_OUTPUT_H
#define AES67_OUTPUT_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include "aes67_ptp.h"
#include "aes67_sdp.h"
#include "aes67_sap.h"

// Configuration AES67
typedef struct {
    char destination_ip[16];
    int destination_port;
    int sample_rate;
    int channels;
    int bit_depth;
    bool multicast;
    bool active;
    int ttl;          // TTL multicast
    int dscp;         // DSCP value (e.g., 46 for EF)
    char outgoing_if[16]; // Interface address for IP_MULTICAST_IF (optional)
    bool multicast_loopback;
    float packet_duration_ms; // Durée des paquets en ms (0.125 à 4.0)
} aes67_config_t;

// Instance de sortie AES67
typedef struct {
    aes67_config_t config;
    ptp_state_t ptp_state;
    sdp_state_t sdp_state;
    sap_state_t sap_state;
    void* instance;
    void* output_buffer;
    size_t buffer_size;
    void* packet_buffer;
    size_t packet_buffer_size;
    void* float_packet_buffer;   // 1ms de float interleavé
    size_t float_packet_buffer_size;

    // Ring buffer d'entrée (float interleavé) et thread d'envoi
    void* input_rb_handle;      // opaque ringbuffer handle (ringbuf_t*)
    void* input_rb_storage;     // allocation brute pour data
    size_t input_rb_capacity;
    void* sender_thread_handle; // pthread_t*
    bool sender_running;
    size_t samples_per_packet; // par canal (1 ms)

    // Métriques simples
    unsigned long long packets_sent;
    unsigned long long bytes_sent;
    double last_interval_us;
    bool initialized;
} aes67_output_t;

// Fonctions principales
int aes67_output_init(aes67_output_t* output);
int aes67_output_send(aes67_output_t* output, const void* audio_data, size_t data_size);
void aes67_output_cleanup(aes67_output_t* output);
bool aes67_output_is_active(const aes67_output_t* output);

// Fonctions de contrôle
int aes67_output_enable(aes67_output_t* output);
int aes67_output_disable(aes67_output_t* output);

// Fonctions de configuration
int aes67_output_set_destination(aes67_output_t* output, const char* ip, int port);
int aes67_output_set_multicast(aes67_output_t* output, bool enable);
int aes67_output_set_audio_format(aes67_output_t* output, int sample_rate, int channels, int bit_depth);
int aes67_output_set_ttl(aes67_output_t* output, int ttl);
int aes67_output_set_dscp(aes67_output_t* output, int dscp);
int aes67_output_set_interface(aes67_output_t* output, const char* if_addr);
int aes67_output_set_multicast_loopback(aes67_output_t* output, bool enable);
int aes67_output_set_packet_duration(aes67_output_t* output, float duration_ms);

// Fonctions de statut et d'information
const char* aes67_output_get_status_string(const aes67_output_t* output);
int aes67_output_get_latency_ms(const aes67_output_t* output);

// Fonctions PTP, SDP et SAP
int aes67_output_enable_ptp(aes67_output_t* output, bool enable);
int aes67_output_set_ptp_enabled(aes67_output_t* output, bool enable);
int aes67_output_set_sap_enabled(aes67_output_t* output, bool enable);
int aes67_output_generate_sdp(aes67_output_t* output);
const char* aes67_output_get_sdp(aes67_output_t* output);
int aes67_output_start_sap_announcements(aes67_output_t* output);
int aes67_output_stop_sap_announcements(aes67_output_t* output);

// Fonction pour obtenir l'instance globale
aes67_output_t* aes67_output_get_global_instance(void);

#ifdef __cplusplus
}
#endif

#endif // AES67_OUTPUT_H
