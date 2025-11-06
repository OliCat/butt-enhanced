#!/bin/bash

# 🎵 Test BUTT AES67 Corrigé
# ===========================

echo "🎵 Test BUTT AES67 avec correction de fréquence"
echo "==============================================="

# Configuration
AES67_IP="239.69.145.58"
AES67_PORT="5004"
TEST_DURATION="30"

echo ""
echo "📡 Configuration AES67:"
echo "  IP: ${AES67_IP}"
echo "  Port: ${AES67_PORT}"
echo "  Durée de test: ${TEST_DURATION}s"
echo ""

# Créer un fichier SDP avec la fréquence réelle de BUTT
cat > test_butt_fixed.sdp << EOF
v=0
o=- 0 0 IN IP4 ${AES67_IP}
s=BUTT AES67 Stream (Fixed)
c=IN IP4 ${AES67_IP}/32
t=0 0
m=audio ${AES67_PORT} RTP/AVP 96
a=rtpmap:96 L24/44100/2
a=recvonly
EOF

echo "📁 Fichier SDP créé: test_butt_fixed.sdp"
echo ""

echo "🎯 Instructions de test:"
echo "========================"
echo ""
echo "1. Lancer BUTT dans un terminal:"
echo "   ./src/butt"
echo ""
echo "2. Tester la réception avec FFmpeg:"
echo "   ffmpeg -protocol_whitelist file,udp,rtp -i test_butt_fixed.sdp -t ${TEST_DURATION} -acodec pcm_s16le -ar 44100 -ac 2 -f wav test_output.wav"
echo ""
echo "3. Tester avec VLC:"
echo "   vlc --intf dummy test_butt_fixed.sdp"
echo ""
echo "4. Tester avec Stream Monitor:"
echo "   - Ouvrir Stream Monitor"
echo "   - File → Open SDP File"
echo "   - Sélectionner: test_butt_fixed.sdp"
echo ""

echo "📋 Checklist de validation:"
echo "==========================="
echo "□ BUTT se lance sans erreur"
echo "□ Logs AES67 montrent la transmission"
echo "□ FFmpeg détecte et enregistre le flux"
echo "□ VLC peut lire le flux"
echo "□ Stream Monitor détecte le flux"
echo "□ Audio audible et de bonne qualité"
echo ""

echo "🔍 Vérifications rapides:"
echo "========================"
echo ""
echo "1. Vérifier que BUTT envoie:"
echo "   sudo tcpdump -i any udp port ${AES67_PORT} -c 10 -vv"
echo ""
echo "2. Vérifier les logs BUTT:"
echo "   grep 'AES67' dans les logs de BUTT"
echo ""
echo "3. Vérifier la fréquence d'échantillonnage:"
echo "   Les logs doivent montrer 44100Hz"
echo ""

echo "🚨 Si le problème persiste:"
echo "==========================="
echo ""
echo "1. Vérifier la configuration audio de BUTT:"
echo "   - Sample Rate dans les paramètres"
echo "   - Format audio configuré"
echo ""
echo "2. Tester avec AES67 Monitor (gratuit):"
echo "   https://aes67.app/"
echo ""
echo "3. Vérifier la compatibilité réseau:"
echo "   - Multicast activé"
echo "   - Pare-feu désactivé"
echo ""

echo "✅ Test terminé !" 