#ifndef AES67_SAP_H
#define AES67_SAP_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Configuration SAP
#define SAP_DEFAULT_PORT 9875
#define SAP_DEFAULT_TTL 32
#define SAP_DEFAULT_INTERVAL_MS 5000

typedef struct {
    char origin_address[64];
    char session_name[256];
    char session_info[512];
    uint16_t sap_port;
    uint8_t sap_ttl;
    uint32_t announcement_interval_ms;
    bool enabled;
} sap_config_t;

typedef struct {
    sap_config_t config;
    bool initialized;
    int sock_fd;
    uint32_t last_announcement;
    char* sdp_content;
    size_t sdp_length;
} sap_state_t;

// Fonctions SAP
int sap_init(sap_state_t* sap_state);
int sap_set_config(sap_state_t* sap_state, const sap_config_t* config);
int sap_set_sdp_content(sap_state_t* sap_state, const char* sdp_content);
int sap_start_announcements(sap_state_t* sap_state);
int sap_stop_announcements(sap_state_t* sap_state);
int sap_send_announcement(sap_state_t* sap_state);
void sap_cleanup(sap_state_t* sap_state);

// Fonctions utilitaires
uint32_t sap_calculate_hash(const char* sdp_content);
int sap_create_multicast_socket(const char* multicast_ip, int port, int ttl);

#ifdef __cplusplus
}
#endif

#endif // AES67_SAP_H 