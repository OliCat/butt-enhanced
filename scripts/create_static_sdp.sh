#!/bin/bash

# 🎵 Création SDP avec Payload Types Statiques
# ============================================

echo "🎵 Création SDP avec Payload Types Statiques"
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
# SDP avec Payload Type 10 (PCM 16-bit)
# ========================================
cat > sdp_static_10.sdp << EOF
v=0
o=- 0 0 IN IP4 ${AES67_IP}
s=BUTT AES67 Stream (Static PT10)
c=IN IP4 ${AES67_IP}/32
t=0 0
m=audio ${AES67_PORT} RTP/AVP 10
a=rtpmap:10 L16/44100/2
a=recvonly
EOF

# ========================================
# SDP avec Payload Type 11 (PCM 16-bit)
# ========================================
cat > sdp_static_11.sdp << EOF
v=0
o=- 0 0 IN IP4 ${AES67_IP}
s=BUTT AES67 Stream (Static PT11)
c=IN IP4 ${AES67_IP}/32
t=0 0
m=audio ${AES67_PORT} RTP/AVP 11
a=rtpmap:11 L16/48000/2
a=recvonly
EOF

# ========================================
# SDP avec Payload Type 97 (PCM 24-bit)
# ========================================
cat > sdp_static_97.sdp << EOF
v=0
o=- 0 0 IN IP4 ${AES67_IP}
s=BUTT AES67 Stream (Static PT97)
c=IN IP4 ${AES67_IP}/32
t=0 0
m=audio ${AES67_PORT} RTP/AVP 97
a=rtpmap:97 L24/44100/2
a=recvonly
EOF

# ========================================
# SDP avec Payload Type 98 (PCM 24-bit)
# ========================================
cat > sdp_static_98.sdp << EOF
v=0
o=- 0 0 IN IP4 ${AES67_IP}
s=BUTT AES67 Stream (Static PT98)
c=IN IP4 ${AES67_IP}/32
t=0 0
m=audio ${AES67_PORT} RTP/AVP 98
a=rtpmap:98 L24/48000/2
a=recvonly
EOF

echo "✅ Fichiers SDP créés avec Payload Types statiques:"
echo "  - sdp_static_10.sdp (PT10, L16/44100/2)"
echo "  - sdp_static_11.sdp (PT11, L16/48000/2)"
echo "  - sdp_static_97.sdp (PT97, L24/44100/2)"
echo "  - sdp_static_98.sdp (PT98, L24/48000/2)"
echo ""

echo "🎯 Tests recommandés:"
echo "===================="
echo ""
echo "1. Test VLC avec SDP statique:"
echo "   vlc --intf dummy sdp_static_10.sdp"
echo "   vlc --intf dummy sdp_static_11.sdp"
echo "   vlc --intf dummy sdp_static_97.sdp"
echo "   vlc --intf dummy sdp_static_98.sdp"
echo ""
echo "2. Test FFmpeg avec SDP statique:"
echo "   ffmpeg -protocol_whitelist file,udp,rtp -i sdp_static_10.sdp -f null -"
echo "   ffmpeg -protocol_whitelist file,udp,rtp -i sdp_static_11.sdp -f null -"
echo ""
echo "3. Test Stream Monitor:"
echo "   - Ouvrir Stream Monitor"
echo "   - File → Open SDP File"
echo "   - Tester chaque fichier SDP"
echo ""

echo "📋 Payload Types statiques vs dynamiques:"
echo "========================================="
echo ""
echo "Payload Types statiques (recommandés):"
echo "  - PT10: L16/44100/2 (PCM 16-bit, 44.1kHz)"
echo "  - PT11: L16/48000/2 (PCM 16-bit, 48kHz)"
echo "  - PT97: L24/44100/2 (PCM 24-bit, 44.1kHz)"
echo "  - PT98: L24/48000/2 (PCM 24-bit, 48kHz)"
echo ""
echo "Payload Type dynamique (problématique):"
echo "  - PT96: L24/44100/2 (PCM 24-bit, 44.1kHz)"
echo ""

echo "🚨 Si aucun SDP statique ne fonctionne:"
echo "======================================"
echo ""
echo "1. Vérifier que BUTT envoie bien le bon format:"
echo "   sudo tcpdump -i any udp port ${AES67_PORT} -c 20 -vv"
echo ""
echo "2. Tester avec AES67 Monitor (gratuit):"
echo "   https://aes67.app/"
echo ""
echo "3. Modifier BUTT pour utiliser un Payload Type statique"
echo ""

echo "✅ Script terminé !" 