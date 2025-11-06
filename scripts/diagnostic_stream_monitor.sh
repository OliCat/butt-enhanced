#!/bin/bash

# 🔍 Diagnostic Stream Monitor - BUTT AES67
# =========================================

echo "🔍 Diagnostic Stream Monitor avec BUTT AES67"
echo "============================================"

# Configuration AES67
AES67_IP="239.69.145.58"
AES67_PORT="5004"

echo ""
echo "📡 Configuration AES67:"
echo "  IP: ${AES67_IP}"
echo "  Port: ${AES67_PORT}"
echo ""

# ========================================
# ÉTAPE 1: Vérifier que BUTT envoie
# ========================================
echo "🔍 ÉTAPE 1: Vérification transmission BUTT"
echo "----------------------------------------"

echo "Lance BUTT et vérifie la transmission..."
echo "Dans un autre terminal, exécute:"
echo "sudo tcpdump -i any udp port ${AES67_PORT} -c 20 -vv"
echo ""

# ========================================
# ÉTAPE 2: Créer SDP avec fréquence correcte
# ========================================
echo "🔍 ÉTAPE 2: Création SDP compatible"
echo "-----------------------------------"

# Créer SDP avec 44.1kHz (fréquence réelle de BUTT)
cat > stream_monitor_44100.sdp << EOF
v=0
o=- 0 0 IN IP4 ${AES67_IP}
s=BUTT AES67 Stream (44.1kHz)
c=IN IP4 ${AES67_IP}/32
t=0 0
m=audio ${AES67_PORT} RTP/AVP 96
a=rtpmap:96 L24/44100/2
a=recvonly
EOF

# Créer SDP avec 48kHz (standard AES67)
cat > stream_monitor_48000.sdp << EOF
v=0
o=- 0 0 IN IP4 ${AES67_IP}
s=BUTT AES67 Stream (48kHz)
c=IN IP4 ${AES67_IP}/32
t=0 0
m=audio ${AES67_PORT} RTP/AVP 96
a=rtpmap:96 L24/48000/2
a=recvonly
EOF

echo "✅ Fichiers SDP créés:"
echo "  - stream_monitor_44100.sdp (fréquence réelle)"
echo "  - stream_monitor_48000.sdp (standard AES67)"
echo ""

# ========================================
# ÉTAPE 3: Tests avec différents logiciels
# ========================================
echo "🔍 ÉTAPE 3: Tests de réception"
echo "-------------------------------"

echo "Test 1: FFmpeg avec 44.1kHz"
echo "ffmpeg -protocol_whitelist file,udp,rtp -i stream_monitor_44100.sdp -f null -"
echo ""

echo "Test 2: FFmpeg avec 48kHz"
echo "ffmpeg -protocol_whitelist file,udp,rtp -i stream_monitor_48000.sdp -f null -"
echo ""

echo "Test 3: VLC avec 44.1kHz"
echo "vlc --intf dummy stream_monitor_44100.sdp"
echo ""

echo "Test 4: GStreamer"
echo "gst-launch-1.0 sdp://${AES67_IP}:${AES67_PORT} ! audioconvert ! autoaudiosink"
echo ""

# ========================================
# ÉTAPE 4: Instructions Stream Monitor
# ========================================
echo "🔍 ÉTAPE 4: Configuration Stream Monitor"
echo "----------------------------------------"

echo "Méthode 1: Ouvrir fichier SDP"
echo "1. Ouvrir Stream Monitor"
echo "2. File → Open SDP File"
echo "3. Sélectionner: stream_monitor_44100.sdp"
echo "4. Vérifier que le flux apparaît"
echo ""

echo "Méthode 2: Découverte automatique"
echo "1. Ouvrir Stream Monitor"
echo "2. Vérifier que SAP est activé"
echo "3. Attendre la découverte automatique"
echo "4. Si rien n'apparaît, utiliser Méthode 1"
echo ""

echo "Méthode 3: Configuration manuelle"
echo "1. Ouvrir Stream Monitor"
echo "2. Add Stream → Manual"
echo "3. IP: ${AES67_IP}"
echo "4. Port: ${AES67_PORT}"
echo "5. Format: L24/44100/2"
echo ""

# ========================================
# ÉTAPE 5: Diagnostic avancé
# ========================================
echo "🔍 ÉTAPE 5: Diagnostic avancé"
echo "-------------------------------"

echo "Si Stream Monitor ne détecte toujours rien:"
echo ""
echo "1. Vérifier les logs Stream Monitor:"
echo "   - Ouvrir Console.app"
echo "   - Filtrer par 'Stream Monitor'"
echo "   - Chercher les erreurs"
echo ""

echo "2. Vérifier la compatibilité réseau:"
echo "   - Interface réseau active"
echo "   - Multicast activé"
echo "   - Pare-feu désactivé"
echo ""

echo "3. Tester avec un autre flux AES67:"
echo "   - Utiliser un générateur AES67"
echo "   - Vérifier que Stream Monitor fonctionne"
echo ""

echo "4. Contacter le support:"
echo "   - Version Stream Monitor"
echo "   - Logs d'erreur"
echo "   - Configuration réseau"
echo ""

# ========================================
# ÉTAPE 6: Solutions alternatives
# ========================================
echo "🔍 ÉTAPE 6: Solutions alternatives"
echo "---------------------------------"

echo "Si Stream Monitor ne fonctionne pas:"
echo ""
echo "Alternative 1: AES67 Monitor (gratuit)"
echo "https://aes67.app/"
echo ""

echo "Alternative 2: VLC avec interface graphique"
echo "vlc rtp://@${AES67_IP}:${AES67_PORT}"
echo ""

echo "Alternative 3: FFmpeg avec sortie audio"
echo "ffmpeg -protocol_whitelist file,udp,rtp -i stream_monitor_44100.sdp -acodec pcm_s16le -ar 44100 -ac 2 -f wav - | aplay"
echo ""

echo "✅ Diagnostic terminé !" 