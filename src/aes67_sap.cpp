#include "aes67_sap.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <time.h>
#include <pthread.h>

// Structure pour le thread d'annonce
typedef struct {
    sap_state_t* sap_state;
    bool running;
    pthread_t thread;
} sap_thread_data_t;

static sap_thread_data_t g_sap_thread = {0};

// Initialiser SAP
int sap_init(sap_state_t* sap_state) {
    if (!sap_state) {
        return -1;
    }
    
    memset(sap_state, 0, sizeof(sap_state_t));
    
    // Configuration par défaut
    strcpy(sap_state->config.origin_address, "127.0.0.1");
    strcpy(sap_state->config.session_name, "BUTT AES67 Stream");
    strcpy(sap_state->config.session_info, "Broadcast Using This Tool - AES67 Audio Stream");
    sap_state->config.sap_port = SAP_DEFAULT_PORT;
    sap_state->config.sap_ttl = SAP_DEFAULT_TTL;
    sap_state->config.announcement_interval_ms = SAP_DEFAULT_INTERVAL_MS;
    sap_state->config.enabled = false;
    
    sap_state->initialized = true;
    sap_state->sock_fd = -1;
    
    printf("SAP: Initialisé avec port %d, TTL %d\n", 
           sap_state->config.sap_port, sap_state->config.sap_ttl);
    
    return 0;
}

// Créer un socket multicast pour SAP
int sap_create_multicast_socket(const char* multicast_ip, int port, int ttl) {
    int sock_fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (sock_fd < 0) {
        perror("SAP: Erreur création socket");
        return -1;
    }
    
    // Configurer TTL
    if (setsockopt(sock_fd, IPPROTO_IP, IP_MULTICAST_TTL, &ttl, sizeof(ttl)) < 0) {
        perror("SAP: Erreur configuration TTL");
        close(sock_fd);
        return -1;
    }
    
    // Configurer l'adresse de destination
    struct sockaddr_in dest_addr;
    memset(&dest_addr, 0, sizeof(dest_addr));
    dest_addr.sin_family = AF_INET;
    dest_addr.sin_port = htons(port);
    dest_addr.sin_addr.s_addr = inet_addr(multicast_ip);
    
    if (connect(sock_fd, (struct sockaddr*)&dest_addr, sizeof(dest_addr)) < 0) {
        perror("SAP: Erreur connexion multicast");
        close(sock_fd);
        return -1;
    }
    
    return sock_fd;
}

// Calculer le hash du contenu SDP
uint32_t sap_calculate_hash(const char* sdp_content) {
    if (!sdp_content) {
        return 0;
    }
    
    uint32_t hash = 0;
    size_t len = strlen(sdp_content);
    
    for (size_t i = 0; i < len; i++) {
        hash = ((hash << 5) + hash) + sdp_content[i]; // hash * 33 + c
    }
    
    return hash;
}

// Envoyer une annonce SAP
int sap_send_announcement(sap_state_t* sap_state) {
    if (!sap_state || !sap_state->initialized || !sap_state->sdp_content) {
        return -1;
    }
    
    if (sap_state->sock_fd < 0) {
        // Créer le socket multicast
        sap_state->sock_fd = sap_create_multicast_socket(
            "224.2.127.254", // Adresse multicast SAP standard
            sap_state->config.sap_port,
            sap_state->config.sap_ttl
        );
        
        if (sap_state->sock_fd < 0) {
            return -1;
        }
    }
    
    // Construire le message SAP
    uint32_t hash = sap_calculate_hash(sap_state->sdp_content);
    uint32_t msg_type = 0; // 0 = annonce, 1 = suppression
    uint32_t auth_len = 0; // Pas d'authentification pour l'instant
    
    // Taille totale du message
    size_t msg_size = 8 + auth_len + sap_state->sdp_length; // Header + auth + SDP
    char* msg = (char*)malloc(msg_size);
    if (!msg) {
        return -1;
    }
    
    // Construire l'en-tête SAP
    uint8_t* header = (uint8_t*)msg;
    header[0] = 0x20; // Version 2, pas d'encryption, pas d'authentification
    header[1] = msg_type;
    header[2] = (hash >> 24) & 0xFF;
    header[3] = (hash >> 16) & 0xFF;
    header[4] = (hash >> 8) & 0xFF;
    header[5] = hash & 0xFF;
    header[6] = (auth_len >> 8) & 0xFF;
    header[7] = auth_len & 0xFF;
    
    // Copier le contenu SDP
    if (auth_len > 0) {
        // Ici on ajouterait l'authentification si nécessaire
    }
    
    memcpy(msg + 8 + auth_len, sap_state->sdp_content, sap_state->sdp_length);
    
    // Envoyer le message
    ssize_t sent = send(sap_state->sock_fd, msg, msg_size, 0);
    free(msg);
    
    if (sent < 0) {
        perror("SAP: Erreur envoi annonce");
        return -1;
    }
    
    printf("SAP: Annonce envoyée - %zu bytes (hash: 0x%08X)\n", sent, hash);
    sap_state->last_announcement = (uint32_t)time(NULL);
    
    return 0;
}

// Thread d'annonce périodique
static void* sap_announcement_thread(void* arg) {
    sap_thread_data_t* thread_data = (sap_thread_data_t*)arg;
    sap_state_t* sap_state = thread_data->sap_state;
    
    printf("SAP: Thread d'annonce démarré\n");
    
    while (thread_data->running && sap_state->config.enabled) {
        sap_send_announcement(sap_state);
        
        // Attendre l'intervalle en petits incréments pour réagir rapidement à l'arrêt
        int interval_ms = sap_state->config.announcement_interval_ms;
        int elapsed_ms = 0;
        while (elapsed_ms < interval_ms && thread_data->running) {
            usleep(10000); // 10ms
            elapsed_ms += 10;
        }
    }
    
    thread_data->running = false; // Signaler la fin du thread
    printf("SAP: Thread d'annonce arrêté\n");
    return NULL;
}

// Démarrer les annonces SAP
int sap_start_announcements(sap_state_t* sap_state) {
    if (!sap_state || !sap_state->initialized) {
        return -1;
    }
    
    if (g_sap_thread.running) {
        printf("SAP: Annonces déjà en cours\n");
        return 0;
    }
    
    sap_state->config.enabled = true;
    g_sap_thread.sap_state = sap_state;
    g_sap_thread.running = true;
    
    if (pthread_create(&g_sap_thread.thread, NULL, sap_announcement_thread, &g_sap_thread) != 0) {
        perror("SAP: Erreur création thread");
        g_sap_thread.running = false;
        sap_state->config.enabled = false;
        return -1;
    }
    
    printf("SAP: Annonces démarrées (intervalle: %d ms)\n", 
           sap_state->config.announcement_interval_ms);
    
    return 0;
}

// Arrêter les annonces SAP
int sap_stop_announcements(sap_state_t* sap_state) {
    if (!sap_state) {
        return -1;
    }
    
    if (!g_sap_thread.running) {
        return 0;
    }
    
    g_sap_thread.running = false;
    sap_state->config.enabled = false;
    
    // Attendre avec timeout pour éviter un blocage
    const int max_wait_ms = 500;
    const int check_interval_ms = 10;
    int waited_ms = 0;
    
    while (g_sap_thread.running && waited_ms < max_wait_ms) {
        usleep(check_interval_ms * 1000);
        waited_ms += check_interval_ms;
    }
    
    if (!g_sap_thread.running) {
        pthread_join(g_sap_thread.thread, NULL);
        printf("SAP: Annonces arrêtées proprement\n");
    } else {
        printf("SAP: Warning - Thread n'a pas répondu dans les %dms, détachement forcé\n", max_wait_ms);
        pthread_detach(g_sap_thread.thread);
    }
    
    return 0;
}

// Définir le contenu SDP
int sap_set_sdp_content(sap_state_t* sap_state, const char* sdp_content) {
    if (!sap_state || !sap_state->initialized || !sdp_content) {
        return -1;
    }
    
    // Libérer l'ancien contenu
    if (sap_state->sdp_content) {
        free(sap_state->sdp_content);
    }
    
    // Allouer et copier le nouveau contenu
    sap_state->sdp_length = strlen(sdp_content);
    sap_state->sdp_content = (char*)malloc(sap_state->sdp_length + 1);
    if (!sap_state->sdp_content) {
        return -1;
    }
    
    strcpy(sap_state->sdp_content, sdp_content);
    
    printf("SAP: Contenu SDP défini (%zu bytes)\n", sap_state->sdp_length);
    
    return 0;
}

// Définir la configuration SAP
int sap_set_config(sap_state_t* sap_state, const sap_config_t* config) {
    if (!sap_state || !sap_state->initialized || !config) {
        return -1;
    }
    
    memcpy(&sap_state->config, config, sizeof(sap_config_t));
    
    printf("SAP: Configuration mise à jour\n");
    
    return 0;
}

// Nettoyer SAP
void sap_cleanup(sap_state_t* sap_state) {
    if (!sap_state) {
        return;
    }
    
    // Arrêter les annonces
    sap_stop_announcements(sap_state);
    
    // Fermer le socket
    if (sap_state->sock_fd >= 0) {
        close(sap_state->sock_fd);
        sap_state->sock_fd = -1;
    }
    
    // Libérer le contenu SDP
    if (sap_state->sdp_content) {
        free(sap_state->sdp_content);
        sap_state->sdp_content = NULL;
    }
    
    sap_state->initialized = false;
    
    printf("SAP: Nettoyage terminé\n");
} 