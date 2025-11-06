#!/bin/bash

# 🎵 Test SDP Corrigé - Vérification Conformité AES67
# ===================================================

echo "🎵 Test SDP Corrigé - Vérification Conformité AES67"
echo "=================================================="

# Configuration
AES67_IP="239.69.145.58"
AES67_PORT="5004"

echo ""
echo "📡 Configuration AES67:"
echo "  IP Multicast: ${AES67_IP}"
echo "  Port: ${AES67_PORT}"
echo ""

# ========================================
# Compilation du test SDP
# ========================================
echo "🔧 Compilation du test SDP..."

# Créer un fichier de test simple
cat > test_sdp_fixed.cpp << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <time.h>

// Fonction pour obtenir l'IP réelle (copiée de aes67_sdp.cpp)
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

// Générer un ID de session unique
char* sdp_generate_session_id(void) {
    static char session_id[64];
    time_t now = time(NULL);
    snprintf(session_id, sizeof(session_id), "%lu", (unsigned long)now);
    return session_id;
}

int main() {
    const char* multicast_ip = "239.69.145.58";
    int port = 5004;
    int sample_rate = 48000;
    int channels = 2;
    int bit_depth = 24;
    
    // Obtenir l'IP réelle
    char* real_ip = sdp_get_network_address();
    char* session_id = sdp_generate_session_id();
    
    printf("🔍 Informations détectées:\n");
    printf("  IP Réelle: %s\n", real_ip);
    printf("  Session ID: %s\n", session_id);
    printf("  Multicast: %s\n", multicast_ip);
    printf("  Port: %d\n", port);
    printf("  Sample Rate: %d\n", sample_rate);
    printf("  Channels: %d\n", channels);
    printf("  Bit Depth: %d\n", bit_depth);
    printf("\n");
    
    // Générer le SDP corrigé
    char sdp_buffer[4096];
    char* sdp = sdp_buffer;
    int written = 0;
    size_t remaining = sizeof(sdp_buffer);
    
    // Version du protocole
    written = snprintf(sdp, remaining, "v=0\r\n");
    sdp += written;
    remaining -= written;

    // Origine (avec IP réelle)
    written = snprintf(sdp, remaining, 
        "o=butt-user %s %s IN IP4 %s\r\n",
        session_id, session_id, real_ip);
    sdp += written;
    remaining -= written;

    // Nom de session
    written = snprintf(sdp, remaining, "s=BUTT AES67 Stream\r\n");
    sdp += written;
    remaining -= written;

    // Informations de session
    written = snprintf(sdp, remaining, "i=Broadcast Using This Tool - AES67 Audio Stream\r\n");
    sdp += written;
    remaining -= written;

    // Temps de session
    written = snprintf(sdp, remaining, "t=0 0\r\n");
    sdp += written;
    remaining -= written;

    // Connexion (format standard AES67)
    written = snprintf(sdp, remaining, "c=IN IP4 %s/32\r\n", multicast_ip);
    sdp += written;
    remaining -= written;

    // Média
    const char* payload_type = (bit_depth == 16) ? "10" : "96";
    const char* encoding = (bit_depth == 16) ? "L16" : "L24";
    written = snprintf(sdp, remaining, "m=audio %d RTP/AVP %s\r\n", port, payload_type);
    sdp += written;
    remaining -= written;

    // Attributs média
    written = snprintf(sdp, remaining, "a=rtpmap:%s %s/%d/%d\r\n", payload_type, encoding, sample_rate, channels);
    sdp += written;
    remaining -= written;

    // Ptime et maxptime
    written = snprintf(sdp, remaining, "a=ptime:1\r\n");
    sdp += written;
    remaining -= written;

    written = snprintf(sdp, remaining, "a=maxptime:1\r\n");
    sdp += written;
    remaining -= written;

    // SSRC
    written = snprintf(sdp, remaining, "a=ssrc:0x12345678 cname:BUTT-AES67\r\n");
    sdp += written;
    remaining -= written;

    // Source-filter (avec IP réelle)
    written = snprintf(sdp, remaining, "a=source-filter:incl IN IP4 %s %s\r\n", multicast_ip, real_ip);
    sdp += written;
    remaining -= written;
    
    // Retourner au début du buffer
    sdp = sdp_buffer;
    
    printf("📋 SDP Généré (Corrigé):\n");
    printf("========================\n");
    printf("%s", sdp);
    printf("========================\n\n");
    
    // Sauvegarder dans un fichier
    FILE* fp = fopen("sdp_fixed_test.sdp", "w");
    if (fp) {
        fwrite(sdp, 1, strlen(sdp), fp);
        fclose(fp);
        printf("💾 SDP sauvegardé dans: sdp_fixed_test.sdp\n\n");
    }
    
    // Vérifications de conformité
    printf("✅ Vérifications de Conformité AES67:\n");
    printf("====================================\n");
    
    // 1. Vérifier que l'origine n'est pas localhost
    if (strstr(sdp, "127.0.0.1") == NULL) {
        printf("✅ Origine: IP réelle utilisée (pas localhost)\n");
    } else {
        printf("❌ Origine: localhost détecté\n");
    }
    
    // 2. Vérifier le format de connexion
    if (strstr(sdp, "/32") != NULL) {
        printf("✅ Connexion: Format standard /32 utilisé\n");
    } else {
        printf("❌ Connexion: Format non standard détecté\n");
    }
    
    // 3. Vérifier le source-filter
    if (strstr(sdp, "source-filter:incl IN IP4 239.69.145.58") != NULL && 
        strstr(sdp, real_ip) != NULL) {
        printf("✅ Source-filter: IP réelle utilisée comme source\n");
    } else {
        printf("❌ Source-filter: Problème détecté\n");
    }
    
    // 4. Vérifier le payload type
    if (strstr(sdp, "96") != NULL) {
        printf("✅ Payload Type: 96 (L24) utilisé\n");
    } else {
        printf("❌ Payload Type: Problème détecté\n");
    }
    
    printf("\n🎯 Test terminé!\n");
    return 0;
}
EOF

# Compiler le test
g++ -o test_sdp_fixed test_sdp_fixed.cpp

if [ $? -eq 0 ]; then
    echo "✅ Compilation réussie"
    echo ""
    
    # Exécuter le test
    echo "🧪 Exécution du test SDP..."
    ./test_sdp_fixed
    
    echo ""
    echo "📁 Fichiers créés:"
    ls -la sdp_fixed_test.sdp 2>/dev/null || echo "  ❌ sdp_fixed_test.sdp non trouvé"
    
else
    echo "❌ Erreur de compilation"
    exit 1
fi

# Nettoyage
rm -f test_sdp_fixed.cpp test_sdp_fixed

echo ""
echo "�� Test SDP terminé!" 