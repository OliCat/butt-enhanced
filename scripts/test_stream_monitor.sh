#!/bin/bash

# 🎵 Test Stream Monitor - BUTT AES67
# ===================================

echo "🎵 Test Stream Monitor avec BUTT AES67"
echo "======================================"

# Configuration AES67
AES67_IP="239.69.145.58"
AES67_PORT="5004"

echo ""
echo "📡 Configuration AES67:"
echo "  IP: ${AES67_IP}"
echo "  Port: ${AES67_PORT}"
echo ""

# Créer un fichier SDP compatible Stream Monitor
cat > stream_monitor_test.sdp << EOF
v=0
o=- 0 0 IN IP4 ${AES67_IP}
s=BUTT AES67 Stream
c=IN IP4 ${AES67_IP}/32
t=0 0
m=audio ${AES67_PORT} RTP/AVP 96
a=rtpmap:96 L24/44100/2
a=recvonly
EOF

echo "📁 Fichier SDP créé: stream_monitor_test.sdp"
echo ""

# Test 1: Vérifier que BUTT envoie
echo "🔍 Test 1: Vérification transmission BUTT"
echo "Lance BUTT et vérifie avec:"
echo "sudo tcpdump -i any udp port ${AES67_PORT} -c 10 -vv"
echo ""

# Test 2: Test avec FFmpeg (compatible Stream Monitor)
echo "🔍 Test 2: FFmpeg avec SDP (compatible Stream Monitor)"
echo "Commande:"
echo "ffmpeg -protocol_whitelist file,udp,rtp -i stream_monitor_test.sdp -f null -"
echo ""

# Test 3: Test avec VLC (alternative Stream Monitor)
echo "🔍 Test 3: VLC avec SDP"
echo "Commande:"
echo "vlc --intf dummy stream_monitor_test.sdp"
echo ""

# Test 4: Test avec GStreamer
echo "🔍 Test 4: GStreamer (compatible Stream Monitor)"
echo "Commande:"
echo "gst-launch-1.0 sdp://${AES67_IP}:${AES67_PORT} ! audioconvert ! autoaudiosink"
echo ""

echo "🎯 Instructions pour Stream Monitor:"
echo "1. Ouvrir Stream Monitor"
echo "2. File → Open SDP File"
echo "3. Sélectionner: stream_monitor_test.sdp"
echo "4. Vérifier que le flux apparaît"
echo ""

echo "📋 Checklist de validation:"
echo "□ Stream Monitor détecte le flux"
echo "□ Audio audible dans Stream Monitor"
echo "□ Pas d'erreur 'Unsupported format'"
echo "□ Fréquence d'échantillonnage correcte"
echo ""

echo "🚨 Si Stream Monitor ne détecte toujours rien:"
echo "- Vérifier que BUTT utilise bien 44.1kHz"
echo "- Tester avec un autre logiciel (VLC, FFmpeg)"
echo "- Vérifier les paramètres réseau"
echo "- Contacter le support Stream Monitor"
echo ""

echo "✅ Terminé !" 