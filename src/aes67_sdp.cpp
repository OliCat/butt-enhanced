#include "aes67_sdp.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <time.h>

// Configuration SDP par défaut
static const sdp_config_t default_sdp_config = {
    .session_name = "BUTT AES67 Stream",
    .session_info = "Broadcast Using This Tool - AES67 Audio Stream",
    .origin_username = "",
    .origin_session_id = "",
    .origin_network_type = "IN",
    .origin_address_type = "IP4",
    .origin_address = "",
    .connection_network_type = "IN",
    .connection_address_type = "IP4",
    .connection_address = "",
    .connection_ttl = "32",
    .connection_address_count = "1",
    .session_start_time = 0,
    .session_end_time = 0,
    .media_type = "audio",
    .media_port = 5004,
    .media_protocol = "RTP/AVP",
    .media_format = "",
    .media_ptime = "1",
    .media_maxptime = "1",
    .media_clock_rate = "48000",
    .media_channels = "2",
    .media_encoding_name = "L16",
    .media_payload_type = "10",
    .media_ssrc = "0x12345678",
    .media_cname = "BUTT-AES67",
    .media_origin = "BUTT",
    .media_session = "AES67",
    .media_app = "Audio",
    .media_ttl = "32",
    .media_rsize = "0",
    .media_ssize = "0"
};

// Générer un ID de session unique
char* sdp_generate_session_id(void) {
    static char session_id[64];
    time_t now = time(NULL);
    snprintf(session_id, sizeof(session_id), "%lu", (unsigned long)now);
    return session_id;
}

// Générer un nom d'utilisateur d'origine
char* sdp_generate_origin_username(void) {
    static char username[64];
    snprintf(username, sizeof(username), "butt-user");
    return username;
}

// Obtenir l'adresse réseau locale
char* sdp_get_network_address(void) {
    static char address[64];
    
    // Obtenir l'adresse IP locale de l'interface active
    int sock = socket(AF_INET, SOCK_DGRAM, 0);
    if (sock < 0) {
        strcpy(address, "127.0.0.1");
        return address;
    }
    
    // Se connecter à une adresse externe pour déterminer l'interface locale
    struct sockaddr_in dest_addr;
    memset(&dest_addr, 0, sizeof(dest_addr));
    dest_addr.sin_family = AF_INET;
    dest_addr.sin_port = htons(53); // Port DNS
    dest_addr.sin_addr.s_addr = inet_addr("8.8.8.8"); // Google DNS
    
    if (connect(sock, (struct sockaddr*)&dest_addr, sizeof(dest_addr)) == 0) {
        struct sockaddr_in local_addr;
        socklen_t addr_len = sizeof(local_addr);
        if (getsockname(sock, (struct sockaddr*)&local_addr, &addr_len) == 0) {
            strcpy(address, inet_ntoa(local_addr.sin_addr));
            close(sock);
            return address;
        }
    }
    
    close(sock);
    
    // Fallback : essayer gethostname
    char hostname[256];
    if (gethostname(hostname, sizeof(hostname)) == 0) {
        struct hostent* host = gethostbyname(hostname);
        if (host && host->h_addr_list[0]) {
            struct in_addr addr;
            memcpy(&addr, host->h_addr_list[0], sizeof(addr));
            strcpy(address, inet_ntoa(addr));
            return address;
        }
    }
    
    // Fallback final
    strcpy(address, "127.0.0.1");
    return address;
}

// Initialisation SDP
int sdp_init(sdp_state_t* sdp_state) {
    if (!sdp_state) {
        return -1;
    }

    // Initialiser avec la configuration par défaut
    sdp_state->config = default_sdp_config;
    sdp_state->initialized = false;
    sdp_state->sdp_length = 0;
    sdp_state->session_version = 0;
    sdp_state->media_version = 0;

    // Configurer les valeurs dynamiques
    strcpy(sdp_state->config.origin_username, sdp_generate_origin_username());
    strcpy(sdp_state->config.origin_session_id, sdp_generate_session_id());
    strcpy(sdp_state->config.origin_address, sdp_get_network_address());
    strcpy(sdp_state->config.connection_address, sdp_get_network_address());

    sdp_state->initialized = true;
    printf("SDP: Initialisé avec session ID: %s\n", sdp_state->config.origin_session_id);

    return 0;
}

// Générer la description de session SDP
int sdp_generate_session_description(sdp_state_t* sdp_state, const char* ip, int port, 
                                   int sample_rate, int channels, int bit_depth) {
    if (!sdp_state || !sdp_state->initialized || !ip) {
        return -1;
    }

    // Mettre à jour la version de session
    sdp_state->session_version++;
    sdp_state->media_version++;

    // Configurer les paramètres audio
    snprintf(sdp_state->config.media_clock_rate, sizeof(sdp_state->config.media_clock_rate), "%d", sample_rate);
    snprintf(sdp_state->config.media_channels, sizeof(sdp_state->config.media_channels), "%d", channels);
    sdp_state->config.media_port = port;
    
    // Configurer le payload type selon le bit depth
    if (bit_depth == 16) {
        strcpy(sdp_state->config.media_encoding_name, "L16");
        strcpy(sdp_state->config.media_payload_type, "10");
    } else {
        // Utiliser PT dynamique pour L24 (pratique courante AES67)
        strcpy(sdp_state->config.media_encoding_name, "L24");
        strcpy(sdp_state->config.media_payload_type, "96");
    }

    // Configurer l'adresse de connexion
    strcpy(sdp_state->config.connection_address, ip);
    
    // Configurer l'origine avec l'IP réelle (pas localhost)
    strcpy(sdp_state->config.origin_address, sdp_get_network_address());

    // Générer le contenu SDP
    char* sdp = sdp_state->sdp_content;
    size_t remaining = sizeof(sdp_state->sdp_content);
    int written = 0;

    // Version du protocole
    written = snprintf(sdp, remaining, "v=0\r\n");
    sdp += written;
    remaining -= written;

    // Origine
    written = snprintf(sdp, remaining, 
        "o=%s %s %s %s %s %s\r\n",
        sdp_state->config.origin_username,
        sdp_state->config.origin_session_id,
        sdp_state->config.origin_session_id,
        sdp_state->config.origin_network_type,
        sdp_state->config.origin_address_type,
        sdp_state->config.origin_address);
    sdp += written;
    remaining -= written;

    // Nom de session
    written = snprintf(sdp, remaining, "s=%s\r\n", sdp_state->config.session_name);
    sdp += written;
    remaining -= written;

    // Informations de session
    written = snprintf(sdp, remaining, "i=%s\r\n", sdp_state->config.session_info);
    sdp += written;
    remaining -= written;

    // Temps de session
    written = snprintf(sdp, remaining, "t=%u %u\r\n", 
        sdp_state->config.session_start_time, sdp_state->config.session_end_time);
    sdp += written;
    remaining -= written;

    // Connexion (format standard AES67)
    written = snprintf(sdp, remaining, 
        "c=%s %s %s/%s\r\n",
        sdp_state->config.connection_network_type,
        sdp_state->config.connection_address_type,
        sdp_state->config.connection_address,
        sdp_state->config.connection_ttl);
    sdp += written;
    remaining -= written;

    // Média
    written = snprintf(sdp, remaining, 
        "m=%s %d %s %s\r\n",
        sdp_state->config.media_type,
        sdp_state->config.media_port,
        sdp_state->config.media_protocol,
        sdp_state->config.media_payload_type);
    sdp += written;
    remaining -= written;

    // Attributs média (rtpmap)
    written = snprintf(sdp, remaining, 
        "a=rtpmap:%s %s/%s/%s\r\n",
        sdp_state->config.media_payload_type,
        sdp_state->config.media_encoding_name,
        sdp_state->config.media_clock_rate,
        sdp_state->config.media_channels);
    sdp += written;
    remaining -= written;

    // fmtp pour L24 (conformité interop)
    if (strcmp(sdp_state->config.media_encoding_name, "L24") == 0) {
        written = snprintf(sdp, remaining,
            "a=fmtp:%s channel-order=SMPTE2110\r\n",
            sdp_state->config.media_payload_type);
        sdp += written;
        remaining -= written;
    }

    // Ptime et maxptime
    written = snprintf(sdp, remaining, 
        "a=ptime:%s\r\n",
        sdp_state->config.media_ptime);
    sdp += written;
    remaining -= written;

    written = snprintf(sdp, remaining, 
        "a=maxptime:%s\r\n",
        sdp_state->config.media_maxptime);
    sdp += written;
    remaining -= written;

    // SSRC
    written = snprintf(sdp, remaining, 
        "a=ssrc:%s cname:%s\r\n",
        sdp_state->config.media_ssrc,
        sdp_state->config.media_cname);
    sdp += written;
    remaining -= written;

    // Attributs spécifiques AES67 (source-filter, horloge)
    char* real_ip = sdp_get_network_address();
    written = snprintf(sdp, remaining, 
        "a=source-filter:incl %s %s %s\r\n",
        sdp_state->config.connection_address_type,
        sdp_state->config.connection_address,
        real_ip);
    sdp += written;
    remaining -= written;

    // Indications horloge média et référence PTP (valeurs par défaut)
    written = snprintf(sdp, remaining,
        "a=mediaclk:direct=0\r\n");
    sdp += written;
    remaining -= written;
    written = snprintf(sdp, remaining,
        "a=ts-refclk:ptp=IEEE1588-2008:domain=0\r\n");
    sdp += written;
    remaining -= written;

    // Calculer la longueur totale
    sdp_state->sdp_length = sizeof(sdp_state->sdp_content) - remaining;

    printf("SDP: Description de session générée (%zu bytes)\n", sdp_state->sdp_length);
    return 0;
}

// Obtenir la description de session SDP
const char* sdp_get_session_description(sdp_state_t* sdp_state) {
    if (!sdp_state || !sdp_state->initialized) {
        return NULL;
    }
    return sdp_state->sdp_content;
}

// Configuration des informations de session
int sdp_set_session_info(sdp_state_t* sdp_state, const char* name, const char* info) {
    if (!sdp_state || !sdp_state->initialized) {
        return -1;
    }
    
    if (name) {
        strncpy(sdp_state->config.session_name, name, sizeof(sdp_state->config.session_name) - 1);
        sdp_state->config.session_name[sizeof(sdp_state->config.session_name) - 1] = '\0';
    }
    
    if (info) {
        strncpy(sdp_state->config.session_info, info, sizeof(sdp_state->config.session_info) - 1);
        sdp_state->config.session_info[sizeof(sdp_state->config.session_info) - 1] = '\0';
    }
    
    return 0;
}

// Configuration de l'origine
int sdp_set_origin(sdp_state_t* sdp_state, const char* username, const char* address) {
    if (!sdp_state || !sdp_state->initialized) {
        return -1;
    }
    
    if (username) {
        strncpy(sdp_state->config.origin_username, username, sizeof(sdp_state->config.origin_username) - 1);
        sdp_state->config.origin_username[sizeof(sdp_state->config.origin_username) - 1] = '\0';
    }
    
    if (address) {
        strncpy(sdp_state->config.origin_address, address, sizeof(sdp_state->config.origin_address) - 1);
        sdp_state->config.origin_address[sizeof(sdp_state->config.origin_address) - 1] = '\0';
    }
    
    return 0;
}

// Configuration de la connexion
int sdp_set_connection(sdp_state_t* sdp_state, const char* address, int ttl) {
    if (!sdp_state || !sdp_state->initialized) {
        return -1;
    }
    
    if (address) {
        strncpy(sdp_state->config.connection_address, address, sizeof(sdp_state->config.connection_address) - 1);
        sdp_state->config.connection_address[sizeof(sdp_state->config.connection_address) - 1] = '\0';
    }
    
    if (ttl > 0) {
        snprintf(sdp_state->config.connection_ttl, sizeof(sdp_state->config.connection_ttl), "%d", ttl);
    }
    
    return 0;
}

// Configuration du média
int sdp_set_media(sdp_state_t* sdp_state, const char* type, int port, const char* protocol) {
    if (!sdp_state || !sdp_state->initialized) {
        return -1;
    }
    
    if (type) {
        strncpy(sdp_state->config.media_type, type, sizeof(sdp_state->config.media_type) - 1);
        sdp_state->config.media_type[sizeof(sdp_state->config.media_type) - 1] = '\0';
    }
    
    if (port > 0) {
        sdp_state->config.media_port = (uint16_t)port;
    }
    
    if (protocol) {
        strncpy(sdp_state->config.media_protocol, protocol, sizeof(sdp_state->config.media_protocol) - 1);
        sdp_state->config.media_protocol[sizeof(sdp_state->config.media_protocol) - 1] = '\0';
    }
    
    return 0;
}

// Validation de la configuration SDP
int sdp_validate_config(sdp_state_t* sdp_state) {
    if (!sdp_state || !sdp_state->initialized) {
        return -1;
    }
    
    // Vérifications de base
    if (strlen(sdp_state->config.session_name) == 0) {
        printf("SDP: Erreur - Nom de session manquant\n");
        return -1;
    }
    
    if (strlen(sdp_state->config.connection_address) == 0) {
        printf("SDP: Erreur - Adresse de connexion manquante\n");
        return -1;
    }
    
    if (sdp_state->config.media_port == 0) {
        printf("SDP: Erreur - Port média manquant\n");
        return -1;
    }
    
    printf("SDP: Configuration validée\n");
    return 0;
}

// Nettoyage SDP
void sdp_cleanup(sdp_state_t* sdp_state) {
    if (!sdp_state) {
        return;
    }
    
    sdp_state->initialized = false;
    sdp_state->sdp_length = 0;
    
    printf("SDP: Nettoyage terminé\n");
} 