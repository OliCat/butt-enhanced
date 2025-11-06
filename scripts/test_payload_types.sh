#!/bin/bash

# 🔍 Test des Payload Types AES67
# ==============================

echo "🔍 Test des Payload Types AES67"
echo "==============================="

# Configuration AES67
AES67_IP="239.69.145.58"
AES67_PORT="5004"

echo ""
echo "📡 Configuration AES67:"
echo "  IP: ${AES67_IP}"
echo "  Port: ${AES67_PORT}"
echo ""

# ========================================
# ÉTAPE 1: Analyser les paquets RTP
# ========================================
echo "🔍 ÉTAPE 1: Analyse des paquets RTP"
echo "-----------------------------------"

echo "Lance BUTT et analyse les paquets RTP..."
echo "Dans un autre terminal, exécute:"
echo "sudo tcpdump -i any udp port ${AES67_PORT} -c 50 -vv | grep -E '(RTP|payload)'"
echo ""

# ========================================
# ÉTAPE 2: Test avec différents SDP
# ========================================
echo "🔍 ÉTAPE 2: Test avec différents SDP"
echo "------------------------------------"

echo "Test 1: SDP avec Payload Type 10 (L16/44100/2)"
echo "Commande:"
echo "ffmpeg -protocol_whitelist file,udp,rtp -i sdp_static_10.sdp -t 10 -f null -"
echo ""

echo "Test 2: SDP avec Payload Type 11 (L16/48000/2)"
echo "Commande:"
echo "ffmpeg -protocol_whitelist file,udp,rtp -i sdp_static_11.sdp -t 10 -f null -"
echo ""

echo "Test 3: SDP avec Payload Type 97 (L24/44100/2)"
echo "Commande:"
echo "ffmpeg -protocol_whitelist file,udp,rtp -i sdp_static_97.sdp -t 10 -f null -"
echo ""

echo "Test 4: SDP avec Payload Type 98 (L24/48000/2)"
echo "Commande:"
echo "ffmpeg -protocol_whitelist file,udp,rtp -i sdp_static_98.sdp -t 10 -f null -"
echo ""

# ========================================
# ÉTAPE 3: Test VLC avec SDP statiques
# ========================================
echo "🔍 ÉTAPE 3: Test VLC avec SDP statiques"
echo "---------------------------------------"

echo "Test VLC avec Payload Type 10:"
echo "vlc --intf dummy sdp_static_10.sdp"
echo ""

echo "Test VLC avec Payload Type 11:"
echo "vlc --intf dummy sdp_static_11.sdp"
echo ""

echo "Test VLC avec Payload Type 97:"
echo "vlc --intf dummy sdp_static_97.sdp"
echo ""

echo "Test VLC avec Payload Type 98:"
echo "vlc --intf dummy sdp_static_98.sdp"
echo ""

# ========================================
# ÉTAPE 4: Test Stream Monitor
# ========================================
echo "🔍 ÉTAPE 4: Test Stream Monitor"
echo "-------------------------------"

echo "Instructions pour Stream Monitor:"
echo "1. Ouvrir Stream Monitor"
echo "2. File → Open SDP File"
echo "3. Tester dans cet ordre:"
echo "   - sdp_static_10.sdp"
echo "   - sdp_static_11.sdp"
echo "   - sdp_static_97.sdp"
echo "   - sdp_static_98.sdp"
echo ""

# ========================================
# ÉTAPE 5: Analyse des résultats
# ========================================
echo "🔍 ÉTAPE 5: Analyse des résultats"
echo "--------------------------------"

echo "📊 Résultats attendus:"
echo "====================="
echo ""
echo "Si FFmpeg fonctionne avec un SDP → BUTT envoie ce format"
echo "Si VLC fonctionne avec un SDP → Compatible avec Stream Monitor"
echo "Si Stream Monitor détecte le flux → Solution trouvée !"
echo ""

echo "📋 Checklist de validation:"
echo "=========================="
echo "□ FFmpeg détecte le flux avec au moins un SDP"
echo "□ VLC peut lire le flux avec au moins un SDP"
echo "□ Stream Monitor détecte le flux"
echo "□ Audio audible et de bonne qualité"
echo "□ Pas d'erreur 'SDP required'"
echo ""

echo "🎯 Solution recommandée:"
echo "======================="
echo ""
echo "1. Identifier le SDP qui fonctionne avec FFmpeg"
echo "2. Utiliser ce SDP avec Stream Monitor"
echo "3. Si aucun ne fonctionne, modifier BUTT pour utiliser un Payload Type statique"
echo ""

echo "✅ Test terminé !" 