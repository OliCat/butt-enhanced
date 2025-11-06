#ifndef AES67_SDP_H
#define AES67_SDP_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include <stdbool.h>
#include <time.h>

// Configuration SDP AES67
typedef struct {
    char session_name[256];
    char session_info[512];
    char origin_username[64];
    char origin_session_id[64];
    char origin_network_type[16];
    char origin_address_type[16];
    char origin_address[64];
    char connection_network_type[16];
    char connection_address_type[16];
    char connection_address[64];
    char connection_ttl[8];
    char connection_address_count[8];
    uint32_t session_start_time;
    uint32_t session_end_time;
    char media_type[16];
    uint16_t media_port;
    char media_protocol[16];
    char media_format[64];
    char media_ptime[16];
    char media_maxptime[16];
    char media_clock_rate[16];
    char media_channels[8];
    char media_encoding_name[32];
    char media_payload_type[8];
    char media_ssrc[16];
    char media_cname[64];
    char media_origin[64];
    char media_session[64];
    char media_app[64];
    char media_ttl[8];
    char media_rsize[16];
    char media_ssize[16];
} sdp_config_t;

// État SDP
typedef struct {
    sdp_config_t config;
    bool initialized;
    char sdp_content[4096];
    size_t sdp_length;
    uint32_t session_version;
    uint32_t media_version;
} sdp_state_t;

// Fonctions SDP principales
int sdp_init(sdp_state_t* sdp_state);
int sdp_generate_session_description(sdp_state_t* sdp_state, const char* ip, int port, 
                                   int sample_rate, int channels, int bit_depth);
const char* sdp_get_session_description(sdp_state_t* sdp_state);
void sdp_cleanup(sdp_state_t* sdp_state);

// Configuration SDP
int sdp_set_session_info(sdp_state_t* sdp_state, const char* name, const char* info);
int sdp_set_origin(sdp_state_t* sdp_state, const char* username, const char* address);
int sdp_set_connection(sdp_state_t* sdp_state, const char* address, int ttl);
int sdp_set_media(sdp_state_t* sdp_state, const char* type, int port, const char* protocol);

// Utilitaires SDP
char* sdp_generate_session_id(void);
char* sdp_generate_origin_username(void);
char* sdp_get_network_address(void);
int sdp_validate_config(sdp_state_t* sdp_state);

#ifdef __cplusplus
}
#endif

#endif // AES67_SDP_H 