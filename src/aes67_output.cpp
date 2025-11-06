#include "aes67_output.h"
#include "aes67_ptp.h"
#include "aes67_sdp.h"
#include "aes67_sap.h"
#include "audio_convert_vdsp.h"
#include "cfg.h"
#include "util.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <errno.h>
#include <math.h>
#include <fcntl.h>
#include <pthread.h>
#include <time.h>
#include "ringbuffer.h"

// Structure pour l'en-tête RTP
typedef struct {
    uint16_t first_word;  // Version(2) + Padding(1) + Extension(1) + CSRC_Count(4) + Marker(1) + Payload_Type(7)
    uint16_t sequence_number;
    uint32_t timestamp;
    uint32_t ssrc;
} __attribute__((packed)) rtp_header_t;

// Configuration par défaut
static const aes67_config_t default_config = {
    .destination_ip = "239.69.145.58",  // Compatible avec ton environnement (239.69.x.x)
    .destination_port = 5004,
    .sample_rate = 48000,
    .channels = 2,
    .bit_depth = 24,  // 🔧 RETOUR: 24-bit (L24) pour compatibilité AES67 standard
    .multicast = true,
    .active = false,
    .ttl = 32,
    .dscp = 46,
    .outgoing_if = "",
    .multicast_loopback = true,  // ✅ ACTIVÉ pour permettre tests locaux
    .packet_duration_ms = 1.0f  // 1ms par défaut pour compatibilité
};

// Instance globale AES67
static aes67_output_t global_aes67_output = {0};

// Variables globales pour l'instance AES67
static int aes67_socket = -1;
static uint16_t aes67_sequence_number = 0;
static uint32_t aes67_timestamp = 0;

// Fonction pour obtenir l'instance globale
aes67_output_t* aes67_output_get_global_instance(void) {
    return &global_aes67_output;
}

// Variables globales pour PLL et configuration optimisée
static audio_pll_t aes67_pll;
static audio_convert_config_t aes67_convert_config;

// Initialisation de la sortie AES67
static void* aes67_sender_thread(void* arg);

int aes67_output_init(aes67_output_t* output) {
    if (!output) {
        return -1;
    }

    // Sauvegarder les paramètres configurés AVANT de réinitialiser
    char saved_outgoing_if[16];
    bool saved_multicast_loopback = output->config.multicast_loopback;
    int saved_ttl = output->config.ttl;
    int saved_dscp = output->config.dscp;
    strncpy(saved_outgoing_if, output->config.outgoing_if, sizeof(saved_outgoing_if) - 1);
    saved_outgoing_if[sizeof(saved_outgoing_if) - 1] = '\0';

    // Initialiser la configuration avec les valeurs par défaut
    output->config = default_config;
    
    // Restaurer les paramètres sauvegardés
    strncpy(output->config.outgoing_if, saved_outgoing_if, sizeof(output->config.outgoing_if) - 1);
    output->config.outgoing_if[sizeof(output->config.outgoing_if) - 1] = '\0';
    output->config.multicast_loopback = saved_multicast_loopback;
    output->config.ttl = saved_ttl;
    output->config.dscp = saved_dscp;
    
    printf("🔍 DEBUG INIT: Restauré outgoing_if='%s', loopback=%d\n", 
           output->config.outgoing_if, output->config.multicast_loopback);
    
    output->instance = NULL;
    output->output_buffer = NULL;
    output->buffer_size = 0;
    output->initialized = false;

    // Initialiser le module de conversion audio optimisée
    if (audio_convert_init() != 0) {
        fprintf(stderr, "AES67: Erreur lors de l'initialisation du module audio\n");
        return -1;
    }

    // Configuration des conversions optimisées selon cfg
    aes67_convert_config.use_vdsp = cfg.audio_perf.use_vdsp;
    aes67_convert_config.dither_type = (dither_type_t)cfg.audio_perf.dither_type;
    aes67_convert_config.clip_protection = cfg.audio_perf.clip_protection;
    aes67_convert_config.noise_floor_db = -144.0f;

    // Initialiser le mini-PLL si activé
    if (cfg.audio_perf.pll_enabled) {
        if (audio_pll_init(&aes67_pll, (double)output->config.sample_rate, 
                          (double)cfg.audio_perf.pll_window_s) != 0) {
            fprintf(stderr, "AES67: Erreur lors de l'initialisation PLL\n");
            return -1;
        }
        printf("AES67: Mini-PLL initialisé pour stabilisation à %.0f Hz\n", 
               (double)output->config.sample_rate);
    }

    // Initialiser PTP, SDP et SAP
    if (ptp_init(&output->ptp_state) != 0) {
        fprintf(stderr, "AES67: Erreur lors de l'initialisation PTP\n");
        return -1;
    }
    
    if (sdp_init(&output->sdp_state) != 0) {
        fprintf(stderr, "AES67: Erreur lors de l'initialisation SDP\n");
        ptp_cleanup(&output->ptp_state);
        return -1;
    }
    
    if (sap_init(&output->sap_state) != 0) {
        fprintf(stderr, "AES67: Erreur lors de l'initialisation SAP\n");
        ptp_cleanup(&output->ptp_state);
        sdp_cleanup(&output->sdp_state);
        return -1;
    }

    // Créer un socket UDP
    aes67_socket = socket(AF_INET, SOCK_DGRAM, 0);
    if (aes67_socket < 0) {
        fprintf(stderr, "AES67: Erreur lors de la création du socket\n");
        return -1;
    }

    // Options socket selon config
    int ttl = output->config.ttl;
    setsockopt(aes67_socket, IPPROTO_IP, IP_MULTICAST_TTL, &ttl, sizeof(ttl));
    int loop = output->config.multicast_loopback ? 1 : 0;
    int ret_loop = setsockopt(aes67_socket, IPPROTO_IP, IP_MULTICAST_LOOP, &loop, sizeof(loop));
    printf("🔧 AES67: Multicast loopback = %d, setsockopt result = %d (errno=%d)\n", 
           loop, ret_loop, errno);
    int tos = (output->config.dscp & 0x3F) << 2; // DSCP to TOS
    setsockopt(aes67_socket, IPPROTO_IP, IP_TOS, &tos, sizeof(tos));
    if (output->config.outgoing_if[0] != '\0') {
        struct in_addr ifaddr;
        ifaddr.s_addr = inet_addr(output->config.outgoing_if);
        if (ifaddr.s_addr != INADDR_NONE) {
            int ret = setsockopt(aes67_socket, IPPROTO_IP, IP_MULTICAST_IF, &ifaddr, sizeof(ifaddr));
            if (ret == 0) {
                printf("✅ AES67: Interface multicast configurée: %s\n", output->config.outgoing_if);
            } else {
                fprintf(stderr, "❌ AES67: Erreur setsockopt IP_MULTICAST_IF: %s (errno=%d)\n", 
                        strerror(errno), errno);
            }
        } else {
            fprintf(stderr, "❌ AES67: Adresse interface invalide: %s\n", output->config.outgoing_if);
        }
    } else {
        printf("⚠️  AES67: Aucune interface configurée - utilisation interface par défaut\n");
    }
    // Non-bloquant et timeout d'envoi pour éviter blocages à la fermeture
    int flags_nb = fcntl(aes67_socket, F_GETFL, 0);
    fcntl(aes67_socket, F_SETFL, flags_nb | O_NONBLOCK);
    struct timeval snd_timeout; snd_timeout.tv_sec = 0; snd_timeout.tv_usec = 50000; // 50 ms
    setsockopt(aes67_socket, SOL_SOCKET, SO_SNDTIMEO, &snd_timeout, sizeof(snd_timeout));

    // Configurer l'adresse de destination
    struct sockaddr_in dest_addr;
    memset(&dest_addr, 0, sizeof(dest_addr));
    dest_addr.sin_family = AF_INET;
    dest_addr.sin_port = htons(output->config.destination_port);
    dest_addr.sin_addr.s_addr = inet_addr(output->config.destination_ip);

    // Allouer un buffer pour les données audio converties (durée configurable)
    size_t samples_per_buffer = (size_t)(output->config.sample_rate * output->config.packet_duration_ms / 1000.0f);
    if (output->config.bit_depth == 16) {
        output->buffer_size = samples_per_buffer * output->config.channels * 2; // 2 bytes par sample
    } else {
        output->buffer_size = samples_per_buffer * output->config.channels * 3; // 3 bytes par sample
    }
    output->output_buffer = malloc(output->buffer_size);
    if (!output->output_buffer) {
        fprintf(stderr, "AES67: Erreur lors de l'allocation du buffer\n");
        close(aes67_socket);
        return -1;
    }

    // Buffer paquet (RTP header + payload 1ms) réutilisable
    output->packet_buffer_size = sizeof(rtp_header_t) + output->buffer_size;
    output->packet_buffer = malloc(output->packet_buffer_size);
    if (!output->packet_buffer) {
        fprintf(stderr, "AES67: Erreur lors de l'allocation du buffer paquet\n");
        free(output->output_buffer);
        output->output_buffer = NULL;
        close(aes67_socket);
        return -1;
    }

    // Init ringbuffer et thread d'envoi
    output->samples_per_packet = samples_per_buffer; // Durée configurable par canal
    output->float_packet_buffer_size = samples_per_buffer * output->config.channels * sizeof(float);
    output->float_packet_buffer = malloc(output->float_packet_buffer_size);
    if (!output->float_packet_buffer) {
        fprintf(stderr, "AES67: Erreur alloc buffer float\n");
        free(output->packet_buffer);
        free(output->output_buffer);
        close(aes67_socket);
        return -1;
    }
    // Ringbuffer doit pouvoir contenir au moins 200ms pour absorber les gros buffers du mixer
    // Le mixer peut envoyer jusqu'à ~100ms d'un coup (19200 bytes pour 48kHz stéréo)
    output->input_rb_capacity = output->float_packet_buffer_size * 256; // ~256ms
    ringbuf_t* rb = (ringbuf_t*)malloc(sizeof(ringbuf_t));
    if (!rb) {
        fprintf(stderr, "AES67: Erreur alloc ringbuffer struct\n");
        free(output->float_packet_buffer);
        free(output->packet_buffer);
        free(output->output_buffer);
        close(aes67_socket);
        return -1;
    }
    rb_init(rb, (unsigned int)output->input_rb_capacity);
    output->input_rb_handle = rb;

    output->sender_running = true;
    pthread_t* th = (pthread_t*)malloc(sizeof(pthread_t));
    output->sender_thread_handle = th;
    if (pthread_create(th, NULL, aes67_sender_thread, output) != 0) {
        fprintf(stderr, "AES67: Erreur création thread envoi\n");
        output->sender_running = false;
        if (rb) { rb_free(rb); free(rb); }
        free(output->float_packet_buffer);
        free(output->packet_buffer);
        free(output->output_buffer);
        close(aes67_socket);
        return -1;
    }

    output->initialized = true;
    printf("AES67: Sortie initialisée - %s:%d, %dHz, %d canaux, %d bits, %.3fms paquets\n",
           output->config.destination_ip, output->config.destination_port,
           output->config.sample_rate, output->config.channels, output->config.bit_depth,
           output->config.packet_duration_ms);
    
    // 🔍 DIAGNOSTIC: Afficher les détails de configuration
    uint8_t payload_type = (output->config.bit_depth == 16) ? 10 : 96;
    const char* format_name = (output->config.bit_depth == 16) ? "PCM16" : "L24";
    printf("🔍 AES67 CONFIG: Format=%s, PayloadType=%d, Compatibilité=%s\n", 
           format_name, payload_type, 
           (payload_type == 10) ? "ÉLEVÉE (PCM16)" : "LIMITÉE (L24)");

    return 0;
}

// Envoi de données audio via AES67
int aes67_output_send(aes67_output_t* output, const void* audio_data, size_t data_size) {
    static int send_counter = 0;
    
    if (!output || !output->initialized || !audio_data || data_size == 0) {
        if (send_counter < 3) {
            printf("❌ SEND: Invalid params (output=%p, init=%d, data=%p, size=%zu)\n",
                   output, output ? output->initialized : 0, audio_data, data_size);
            send_counter++;
        }
        return -1;
    }

    if (!output->config.active) {
        if (send_counter < 3) {
            printf("⚠️  SEND: AES67 not active (config.active=false)\n");
            send_counter++;
        }
        return 0; // Sortie désactivée, pas d'erreur
    }

    // Écrire les données float interleavées dans le ringbuffer
    ringbuf_t* rb = (ringbuf_t*)output->input_rb_handle;
    int written = rb_write(rb, (char*)audio_data, (unsigned int)data_size);
    
    if (send_counter < 5) {
        int filled = rb_filled(rb);
        printf("✅ SEND: Wrote %zu bytes to ringbuffer, result=%d, filled=%d\n",
               data_size, written, filled);
        send_counter++;
    }
    
    return 0;
}

// Thread d'envoi
static void* aes67_sender_thread(void* arg) {
    aes67_output_t* output = (aes67_output_t*)arg;
    size_t float_block_bytes = output->samples_per_packet * output->config.channels * sizeof(float);
    size_t samples_block_total = output->samples_per_packet * output->config.channels;

    struct sockaddr_in dest_addr;
    memset(&dest_addr, 0, sizeof(dest_addr));
    dest_addr.sin_family = AF_INET;
    dest_addr.sin_port = htons(output->config.destination_port);
    dest_addr.sin_addr.s_addr = inet_addr(output->config.destination_ip);

    printf("🎯 AES67 SENDER THREAD: Démarré (float_block_bytes=%zu)\n", float_block_bytes);

    // Attente avec vérification rapide du flag sender_running
    static int debug_counter = 0;
    while (output->sender_running) {
        ringbuf_t* rb = (ringbuf_t*)output->input_rb_handle;
        int filled = rb_filled(rb);
        bool active = output->config.active;
        
        if (debug_counter < 10) {
            printf("🔍 SENDER: filled=%d, need=%zu, active=%d\n", filled, float_block_bytes, active);
            debug_counter++;
        }
        
        if (!active) {
            // Vérifier sender_running fréquemment pour sortie rapide
            usleep(10000); // 10ms au lieu de 1ms pour réduire la charge CPU
            continue;
        }
        
        // 🔧 CORRECTION: Envoyer même si le buffer n'est pas plein
        // Attendre un minimum de données mais ne pas bloquer indéfiniment
        if (filled < (int)float_block_bytes) {
            if (filled > 0) {
                // Il y a des données partielles, les traiter
                printf("🔍 SENDER: Données partielles disponibles: %d/%zu bytes\n", filled, float_block_bytes);
            } else {
                // Aucune donnée, attendre un peu
                usleep(1000); // 1ms
                continue;
            }
        }
        
        // 🔧 CORRECTION: Vérifier que les données ne sont pas toutes nulles
        // Lire temporairement les données pour vérifier leur contenu
        static float temp_check_buffer[192]; // 384 bytes / 2 (float)
        size_t bytes_to_read = (filled >= (int)float_block_bytes) ? float_block_bytes : filled;
        rb_read_len(rb, (char*)temp_check_buffer, (unsigned int)bytes_to_read);
        
        // Remplir le reste avec du silence si nécessaire
        if (bytes_to_read < float_block_bytes) {
            memset((char*)temp_check_buffer + bytes_to_read, 0, float_block_bytes - bytes_to_read);
        }
        
        // Vérifier si les données contiennent de l'audio
        bool has_audio = false;
        for (size_t i = 0; i < samples_block_total && i < 100; i++) {
            if (fabs(temp_check_buffer[i]) > 0.0001f) {
                has_audio = true;
                break;
            }
        }
        
        if (!has_audio) {
            // Pas d'audio, ne pas remettre dans le ringbuffer (cela causerait des boucles)
            // Juste attendre un peu et continuer
            usleep(1000); // 1ms
            continue;
        }
        
        // Audio présent, copier vers le buffer de traitement
        memcpy(output->float_packet_buffer, temp_check_buffer, float_block_bytes);
        
        // 🔍 DIAGNOSTIC: Confirmer que l'audio est détecté
        static int audio_detected_counter = 0;
        if (audio_detected_counter < 5) {
            float max_audio = 0.0f;
            for (size_t i = 0; i < samples_block_total && i < 100; i++) {
                if (fabs(temp_check_buffer[i]) > max_audio) {
                    max_audio = fabs(temp_check_buffer[i]);
                }
            }
            printf("🔍 AUDIO DETECTED %d: max_audio=%.6f, samples=%zu\n", 
                   audio_detected_counter, max_audio, samples_block_total);
            audio_detected_counter++;
        }
        
        if (debug_counter == 10) {
            printf("📤 SENDER: Audio détecté ! Processing %zu bytes and sending RTP...\n", float_block_bytes);
            debug_counter++;
        }
        
        // 🔍 DIAGNOSTIC: Log périodique pour confirmer l'envoi continu
        static int continuous_send_counter = 0;
        if (continuous_send_counter % 100 == 0) {
            printf("🔄 SENDER: Envoi continu - paquet #%d\n", continuous_send_counter);
        }
        continuous_send_counter++;

        // Mise à jour du mini-PLL si activé
        static uint64_t pll_last_correction_time = 0;
        static double accumulated_correction_samples = 0.0;
        
        if (cfg.audio_perf.pll_enabled) {
            uint64_t timestamp_ns = audio_get_monotonic_time_ns();
            audio_pll_update(&aes67_pll, timestamp_ns, output->samples_per_packet);
            
            // Appliquer la correction PLL au timestamp RTP de façon progressive
            double correction_ppm = audio_pll_get_correction_ppm(&aes67_pll);
            
            // Appliquer la correction si elle est significative (> 1 PPM)
            if (fabs(correction_ppm) > 1.0) {
                // Calculer la correction en échantillons pour ce paquet
                double correction_samples_per_packet = output->samples_per_packet * (correction_ppm * 1e-6);
                accumulated_correction_samples += correction_samples_per_packet;
                
                // Appliquer une correction entière quand on a accumulé assez
                if (fabs(accumulated_correction_samples) >= 1.0) {
                    int correction_samples = (int)round(accumulated_correction_samples);
                    accumulated_correction_samples -= correction_samples;
                    
                    // Log des corrections importantes seulement
                    if (abs(correction_samples) > 0 && 
                        (timestamp_ns - pll_last_correction_time) > 5000000000ULL) { // 5 secondes
                        printf("AES67 PLL: Correction appliquée: %+d échantillons (%.2f PPM)\n", 
                               correction_samples, correction_ppm);
                        pll_last_correction_time = timestamp_ns;
                    }
                }
            }
        }

        // Conversion optimisée avec vDSP
        if (output->config.bit_depth == 16) {
            audio_convert_float_to_pcm16_vdsp((const float*)output->float_packet_buffer, 
                                             (int16_t*)output->output_buffer, 
                                             samples_block_total, &aes67_convert_config);
        } else {
            audio_convert_float_to_l24_vdsp((const float*)output->float_packet_buffer, 
                                           (uint8_t*)output->output_buffer, 
                                           samples_block_total, &aes67_convert_config);
        }

        // 🔍 DIAGNOSTIC: Vérifier la qualité de la conversion audio
        static int diagnostic_counter = 0;
        if (diagnostic_counter < 20) {
            // Vérifier les données d'entrée (float)
            float* input_samples = (float*)output->float_packet_buffer;
            float max_input = 0.0f, min_input = 0.0f;
            for (size_t i = 0; i < samples_block_total && i < 100; i++) {
                if (input_samples[i] > max_input) max_input = input_samples[i];
                if (input_samples[i] < min_input) min_input = input_samples[i];
            }
            
            // Vérifier les données de sortie (PCM)
            if (output->config.bit_depth == 16) {
                int16_t* output_samples = (int16_t*)output->output_buffer;
                int16_t max_output = 0, min_output = 0;
                for (size_t i = 0; i < samples_block_total && i < 100; i++) {
                    if (output_samples[i] > max_output) max_output = output_samples[i];
                    if (output_samples[i] < min_output) min_output = output_samples[i];
                }
                printf("🔍 DIAGNOSTIC %d: Input float [%.6f, %.6f] → Output PCM16 [%d, %d]\n", 
                       diagnostic_counter, min_input, max_input, min_output, max_output);
            } else {
                uint8_t* output_bytes = (uint8_t*)output->output_buffer;
                printf("🔍 DIAGNOSTIC %d: Input float [%.6f, %.6f] → Output L24 bytes [%02x %02x %02x, %02x %02x %02x]\n", 
                       diagnostic_counter, min_input, max_input, 
                       output_bytes[0], output_bytes[1], output_bytes[2],
                       output_bytes[3], output_bytes[4], output_bytes[5]);
            }
            diagnostic_counter++;
        }

        rtp_header_t* hdr = (rtp_header_t*)output->packet_buffer;
        memset(hdr, 0, sizeof(*hdr));
        uint8_t payload_type = (output->config.bit_depth == 16) ? 10 : 96;
        hdr->first_word = htons((2 << 14) | (payload_type << 0));
        hdr->sequence_number = htons(aes67_sequence_number++);
        
        // Le timestamp RTP doit TOUJOURS progresser linéairement
        // PTP peut être utilisé pour synchroniser l'horloge, mais pas pour écraser le timestamp à chaque paquet
        hdr->timestamp = htonl(aes67_timestamp);
        hdr->ssrc = htonl(0x12345678);

        // 🔍 DIAGNOSTIC: Vérifier les en-têtes RTP
        static int rtp_diagnostic_counter = 0;
        if (rtp_diagnostic_counter < 10) {
            printf("🔍 RTP HEADER %d: PT=%d, Seq=%d, TS=%u, SSRC=0x%08x\n", 
                   rtp_diagnostic_counter, payload_type, ntohs(hdr->sequence_number), 
                   ntohl(hdr->timestamp), ntohl(hdr->ssrc));
            rtp_diagnostic_counter++;
        }

        size_t payload_bytes = (output->config.bit_depth == 16)
                                 ? samples_block_total * 2
                                 : samples_block_total * 3;
        void* payload_ptr = (uint8_t*)output->packet_buffer + sizeof(rtp_header_t);
        memcpy(payload_ptr, output->output_buffer, payload_bytes);

        size_t packet_size = sizeof(rtp_header_t) + payload_bytes;
        ssize_t sent = sendto(aes67_socket, output->packet_buffer, packet_size, 0,
                              (struct sockaddr*)&dest_addr, sizeof(dest_addr));
        
        static int send_packet_counter = 0;
        if (send_packet_counter < 10) {
            if (sent < 0) {
                printf("❌ SENDTO ERROR: errno=%d (%s), seq=%d, ts=%u\n",
                       errno, strerror(errno), ntohs(hdr->sequence_number), ntohl(hdr->timestamp));
            } else {
                printf("📡 SENDTO: packet_size=%zu, sent=%zd, seq=%d, ts=%u, payload_bytes=%zu\n",
                       packet_size, sent, ntohs(hdr->sequence_number), ntohl(hdr->timestamp), payload_bytes);
                
                // 🔍 DIAGNOSTIC: Vérifier le contenu du paquet envoyé
                if (send_packet_counter < 3) {
                    uint8_t* packet_data = (uint8_t*)output->packet_buffer;
                    printf("🔍 PACKET DATA %d: Header[0-11]=%02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x\n",
                           send_packet_counter,
                           packet_data[0], packet_data[1], packet_data[2], packet_data[3],
                           packet_data[4], packet_data[5], packet_data[6], packet_data[7],
                           packet_data[8], packet_data[9], packet_data[10], packet_data[11]);
                    printf("🔍 PACKET DATA %d: Payload[0-23]=%02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x\n",
                           send_packet_counter,
                           packet_data[12], packet_data[13], packet_data[14], packet_data[15],
                           packet_data[16], packet_data[17], packet_data[18], packet_data[19],
                           packet_data[20], packet_data[21], packet_data[22], packet_data[23],
                           packet_data[24], packet_data[25], packet_data[26], packet_data[27],
                           packet_data[28], packet_data[29], packet_data[30], packet_data[31],
                           packet_data[32], packet_data[33], packet_data[34], packet_data[35]);
                }
            }
            send_packet_counter++;
        }
        
        if (sent >= 0) {
            output->packets_sent++;
            output->bytes_sent += (unsigned long long)sent;
            aes67_timestamp += (uint32_t)output->samples_per_packet;
        }
    }

    output->sender_running = false; // Signaler la fin du thread
    printf("AES67: Thread sender terminé proprement\n");
    return NULL;
}

// Nettoyage de la sortie AES67
void aes67_output_cleanup(aes67_output_t* output) {
    if (!output) {
        printf("AES67: Cleanup - output NULL\n");
        return;
    }

    printf("AES67: Début cleanup...\n");

    // Désactiver d'abord pour éviter les accès concurrents
    output->config.active = false;

    // Forcer l'arrêt du thread s'il existe
    output->sender_running = false;
    
    // Attendre que les threads se terminent avec timeout
    const int max_wait_ms = 2000; // 2 secondes max
    const int check_interval_ms = 50; // Vérifier toutes les 50ms
    int waited_ms = 0;
    
    while (output->sender_running && waited_ms < max_wait_ms) {
        usleep(check_interval_ms * 1000);
        waited_ms += check_interval_ms;
    }
    
    if (output->sender_running) {
        printf("AES67: Avertissement - Thread envoi n'a pas terminé dans les temps\n");
    }
    
    if (aes67_socket >= 0) {
        // Fermer le socket de manière non-bloquante
        int flags = fcntl(aes67_socket, F_GETFL, 0);
        fcntl(aes67_socket, F_SETFL, flags | O_NONBLOCK);
        close(aes67_socket);
        aes67_socket = -1;
        printf("AES67: Socket fermée\n");
    }

    if (output->sender_thread_handle) {
        output->sender_running = false;
        pthread_t* th = (pthread_t*)output->sender_thread_handle;

        // Sur macOS, pthread_join est bloquant sans option de timeout.
        // On utilise une approche non-bloquante avec un flag volatile.
        const int max_wait_ms = 500;  // Réduit à 500ms
        const int check_interval_ms = 10;  // Vérifier toutes les 10ms
        int waited_ms = 0;
        
        // Attendre que le thread signale sa terminaison via sender_running
        while (output->sender_running && waited_ms < max_wait_ms) {
            usleep(check_interval_ms * 1000);
            waited_ms += check_interval_ms;
        }
        
        if (!output->sender_running) {
            // Le thread a signalé qu'il se termine, attendre proprement
            int join_result = pthread_join(*th, NULL);
            if (join_result == 0) {
                printf("AES67: Thread envoi arrêté proprement\n");
            } else {
                printf("AES67: Erreur pthread_join: %d (%s)\n", join_result, strerror(join_result));
            }
        } else {
            printf("AES67: Warning - Thread n'a pas répondu dans les %dms, détachement forcé\n", max_wait_ms);
            // Détacher le thread pour éviter un blocage lors de la fermeture
            pthread_detach(*th);
        }

        free(th);
        output->sender_thread_handle = NULL;
    }

    if (output->input_rb_handle) {
        ringbuf_t* rb = (ringbuf_t*)output->input_rb_handle;
        if (rb) {
            rb_free(rb);
            free(rb);
        }
        output->input_rb_handle = NULL;
    }

    // Libération sécurisée des buffers avec vérification
    if (output->output_buffer) {
        size_t buffer_size = output->buffer_size;
        free(output->output_buffer);
        output->output_buffer = NULL;
        output->buffer_size = 0;
        printf("AES67: Buffer libéré (%zu bytes)\n", buffer_size);
    }
    if (output->packet_buffer) {
        size_t packet_size = output->packet_buffer_size;
        free(output->packet_buffer);
        output->packet_buffer = NULL;
        output->packet_buffer_size = 0;
        printf("AES67: Buffer paquet libéré (%zu bytes)\n", packet_size);
    }
    if (output->float_packet_buffer) {
        size_t float_size = output->float_packet_buffer_size;
        free(output->float_packet_buffer);
        output->float_packet_buffer = NULL;
        output->float_packet_buffer_size = 0;
        printf("AES67: Buffer float libéré (%zu bytes)\n", float_size);
    }

    // Nettoyer PTP, SDP et SAP avec timeout
    printf("AES67: Cleanup PTP/SDP/SAP...\n");
    ptp_cleanup(&output->ptp_state);
    sdp_cleanup(&output->sdp_state);
    sap_cleanup(&output->sap_state);

    // Nettoyer le module audio
    audio_convert_cleanup();

    output->initialized = false;
    printf("AES67: Sortie nettoyée\n");
}

// Vérifier si la sortie AES67 est active
bool aes67_output_is_active(const aes67_output_t* output) {
    return output && output->initialized && output->config.active;
}

// Configuration de la destination
int aes67_output_set_destination(aes67_output_t* output, const char* ip, int port) {
    if (!output || !ip) {
        return -1;
    }

    strncpy(output->config.destination_ip, ip, sizeof(output->config.destination_ip) - 1);
    output->config.destination_ip[sizeof(output->config.destination_ip) - 1] = '\0';
    output->config.destination_port = port;

    printf("AES67: Destination configurée - %s:%d\n", ip, port);
    return 0;
}

// Configuration du multicast
int aes67_output_set_multicast(aes67_output_t* output, bool enable) {
    if (!output) {
        return -1;
    }

    output->config.multicast = enable;
    printf("AES67: Multicast %s\n", enable ? "activé" : "désactivé");
    return 0;
}

// Configuration du format audio
int aes67_output_set_audio_format(aes67_output_t* output, int sample_rate, int channels, int bit_depth) {
    if (!output) {
        return -1;
    }

    output->config.sample_rate = sample_rate;
    output->config.channels = channels;
    output->config.bit_depth = bit_depth;

    // Recalculer la taille du buffer si nécessaire
    if (output->output_buffer) {
        free(output->output_buffer);
        size_t samples_per_buffer = output->config.sample_rate / 1000; // 1ms de buffer
        if (output->config.bit_depth == 16) {
            output->buffer_size = samples_per_buffer * output->config.channels * 2; // 2 bytes par sample
        } else {
            output->buffer_size = samples_per_buffer * output->config.channels * 3; // 3 bytes par sample
        }
        output->output_buffer = malloc(output->buffer_size);
        if (!output->output_buffer) {
            fprintf(stderr, "AES67: Erreur lors de la réallocation du buffer\n");
            return -1;
        }
        // Recalcule du buffer paquet
        if (output->packet_buffer) {
            free(output->packet_buffer);
        }
        output->packet_buffer_size = sizeof(rtp_header_t) + output->buffer_size;
        output->packet_buffer = malloc(output->packet_buffer_size);
        if (!output->packet_buffer) {
            fprintf(stderr, "AES67: Erreur lors de l'allocation du buffer paquet\n");
            free(output->output_buffer);
            output->output_buffer = NULL;
            return -1;
        }
    }

    printf("AES67: Format audio configuré - %dHz, %d canaux, %d bits\n", sample_rate, channels, bit_depth);
    return 0;
}

// Activer/désactiver PTP
int aes67_output_enable_ptp(aes67_output_t* output, bool enable) {
    if (!output || !output->initialized) {
        return -1;
    }

    if (enable) {
        if (ptp_start_sync(&output->ptp_state) == 0) {
            printf("AES67: PTP activé et synchronisation démarrée\n");
        } else {
            printf("AES67: Erreur lors de l'activation PTP\n");
            return -1;
        }
    } else {
        ptp_stop_sync(&output->ptp_state);
        printf("AES67: PTP désactivé\n");
    }

    return 0;
}

// Générer la description SDP
int aes67_output_generate_sdp(aes67_output_t* output) {
    if (!output || !output->initialized) {
        return -1;
    }

    if (sdp_generate_session_description(&output->sdp_state, 
                                       output->config.destination_ip,
                                       output->config.destination_port,
                                       output->config.sample_rate,
                                       output->config.channels,
                                       output->config.bit_depth) == 0) {
        printf("AES67: Description SDP générée\n");
        return 0;
    } else {
        printf("AES67: Erreur lors de la génération SDP\n");
        return -1;
    }
}

// Obtenir la description SDP
const char* aes67_output_get_sdp(aes67_output_t* output) {
    if (!output || !output->initialized) {
        return NULL;
    }
    return sdp_get_session_description(&output->sdp_state);
}

// Obtenir le statut sous forme de chaîne
const char* aes67_output_get_status_string(const aes67_output_t* output) {
    if (!output) {
        return "Non initialisé";
    }

    if (!output->initialized) {
        return "Non initialisé";
    }

    if (!output->config.active) {
        return "Inactif";
    }

    return "Actif";
}

// Obtenir la latence en millisecondes
int aes67_output_get_latency_ms(const aes67_output_t* output) {
    if (!output || !output->initialized) {
        return -1;
    }

    // Latence estimée basée sur la taille du buffer (10ms par défaut)
    return 10;
}

// Démarrer les annonces SAP
int aes67_output_start_sap_announcements(aes67_output_t* output) {
    if (!output || !output->initialized) {
        return -1;
    }
    
    // Générer le SDP si pas encore fait
    if (aes67_output_generate_sdp(output) != 0) {
        return -1;
    }
    
    // Définir le contenu SDP dans SAP
    const char* sdp_content = aes67_output_get_sdp(output);
    if (!sdp_content) {
        return -1;
    }
    
    if (sap_set_sdp_content(&output->sap_state, sdp_content) != 0) {
        return -1;
    }
    
    // Démarrer les annonces
    if (sap_start_announcements(&output->sap_state) == 0) {
        printf("AES67: Annonces SAP démarrées\n");
        return 0;
    } else {
        printf("AES67: Erreur lors du démarrage des annonces SAP\n");
        return -1;
    }
}

// Arrêter les annonces SAP
int aes67_output_stop_sap_announcements(aes67_output_t* output) {
    if (!output || !output->initialized) {
        return -1;
    }
    
    if (sap_stop_announcements(&output->sap_state) == 0) {
        printf("AES67: Annonces SAP arrêtées\n");
        return 0;
    } else {
        printf("AES67: Erreur lors de l'arrêt des annonces SAP\n");
        return -1;
    }
}

// ============================================================================
// Nouvelles fonctions de contrôle pour l'interface utilisateur
// ============================================================================

// Activer la sortie AES67
int aes67_output_enable(aes67_output_t* output) {
    if (!output) {
        return -1;
    }
    
    if (!output->initialized) {
        // Initialiser si pas encore fait
        if (aes67_output_init(output) != 0) {
            return -1;
        }
    }
    
    output->config.active = true;
    
    // Démarrer les annonces SAP quand AES67 est activé
    aes67_output_start_sap_announcements(output);
    
    printf("AES67: Sortie activée avec annonces SAP\n");
    return 0;
}

// Désactiver la sortie AES67
int aes67_output_disable(aes67_output_t* output) {
    if (!output) {
        return -1;
    }
    
    output->config.active = false;
    
    // Arrêter les annonces SAP quand AES67 est désactivé
    aes67_output_stop_sap_announcements(output);
    
    printf("AES67: Sortie désactivée avec arrêt des annonces SAP\n");
    return 0;
}

// Configurer PTP (alias pour aes67_output_enable_ptp)
int aes67_output_set_ptp_enabled(aes67_output_t* output, bool enable) {
    return aes67_output_enable_ptp(output, enable);
}

// Configurer SAP
int aes67_output_set_sap_enabled(aes67_output_t* output, bool enable) {
    if (!output) {
        return -1;
    }
    
    if (enable) {
        return aes67_output_start_sap_announcements(output);
    } else {
        return aes67_output_stop_sap_announcements(output);
    }
}

int aes67_output_set_ttl(aes67_output_t* output, int ttl) {
    if (!output) return -1;
    output->config.ttl = ttl;
    if (aes67_socket >= 0) {
        setsockopt(aes67_socket, IPPROTO_IP, IP_MULTICAST_TTL, &ttl, sizeof(ttl));
    }
    return 0;
}

int aes67_output_set_dscp(aes67_output_t* output, int dscp) {
    if (!output) return -1;
    output->config.dscp = dscp;
    int tos = (dscp & 0x3F) << 2;
    if (aes67_socket >= 0) {
        setsockopt(aes67_socket, IPPROTO_IP, IP_TOS, &tos, sizeof(tos));
    }
    return 0;
}

int aes67_output_set_interface(aes67_output_t* output, const char* if_addr) {
    if (!output || !if_addr) return -1;
    strncpy(output->config.outgoing_if, if_addr, sizeof(output->config.outgoing_if) - 1);
    output->config.outgoing_if[sizeof(output->config.outgoing_if) - 1] = '\0';
    if (aes67_socket >= 0) {
        struct in_addr ifa; ifa.s_addr = inet_addr(output->config.outgoing_if);
        if (ifa.s_addr != INADDR_NONE) {
            setsockopt(aes67_socket, IPPROTO_IP, IP_MULTICAST_IF, &ifa, sizeof(ifa));
        }
    }
    return 0;
}

int aes67_output_set_multicast_loopback(aes67_output_t* output, bool enable) {
    if (!output) return -1;
    output->config.multicast_loopback = enable;
    int loop = enable ? 1 : 0;
    if (aes67_socket >= 0) {
        setsockopt(aes67_socket, IPPROTO_IP, IP_MULTICAST_LOOP, &loop, sizeof(loop));
    }
    return 0;
}

int aes67_output_set_packet_duration(aes67_output_t* output, float duration_ms) {
    if (!output) return -1;
    
    // Valider la durée (0.125ms à 4.0ms)
    if (duration_ms < 0.125f || duration_ms > 4.0f) {
        fprintf(stderr, "AES67: Durée paquet invalide: %.3fms (doit être entre 0.125 et 4.0ms)\n", duration_ms);
        return -1;
    }
    
    output->config.packet_duration_ms = duration_ms;
    
    // Recalculer la taille des buffers si l'instance est initialisée
    if (output->initialized) {
        size_t samples_per_buffer = (size_t)(output->config.sample_rate * duration_ms / 1000.0f);
        output->samples_per_packet = samples_per_buffer;
        
        printf("AES67: Durée paquet configurée à %.3fms (%zu échantillons)\n", 
               duration_ms, samples_per_buffer);
    }
    
    return 0;
}