#!/bin/bash

# Diagnostic AES67 RTP - Analyse des Paquets
# Ce script capture et analyse les paquets RTP pour diagnostiquer les problèmes AES67

echo "🔍 Diagnostic AES67 RTP - Analyse des Paquets"
echo "============================================="

# Configuration
AES67_IP="239.69.145.58"
AES67_PORT="5004"
CAPTURE_DURATION="30"  # 30 secondes
PCAP_FILE="aes67_packets.pcap"
ANALYSIS_FILE="aes67_analysis.txt"

echo "📡 Configuration:"
echo "  - IP: $AES67_IP"
echo "  - Port: $AES67_PORT"
echo "  - Durée: ${CAPTURE_DURATION}s"
echo "  - Fichier capture: $PCAP_FILE"
echo ""

# Vérifier les outils nécessaires
TOOLS_MISSING=0

if ! command -v tcpdump &> /dev/null; then
    echo "❌ tcpdump non trouvé"
    TOOLS_MISSING=1
fi

if ! command -v tshark &> /dev/null; then
    echo "❌ tshark non trouvé (Wireshark CLI)"
    echo "   Installez avec: brew install wireshark"
    TOOLS_MISSING=1
fi

if [ $TOOLS_MISSING -eq 1 ]; then
    echo ""
    echo "🔧 Installation des outils manquants:"
    echo "   brew install wireshark"
    exit 1
fi

echo "✅ Tous les outils sont disponibles"
echo ""

echo "🎤 Démarrage de la capture RTP..."
echo "   BUTT doit être en cours d'exécution avec AES67 activé"
echo "   Appuyez sur Entrée pour commencer la capture..."
read -r

# Capture des paquets RTP
echo "📹 Capture des paquets RTP en cours..."
sudo tcpdump -i en0 -w "$PCAP_FILE" \
    "udp port $AES67_PORT and dst host $AES67_IP" \
    -c 100 2>/dev/null &

TCPDUMP_PID=$!

echo "   Capture en cours... (PID: $TCPDUMP_PID)"
echo "   Appuyez sur Entrée pour arrêter la capture..."
read -r

# Arrêter la capture
sudo kill $TCPDUMP_PID 2>/dev/null
wait $TCPDUMP_PID 2>/dev/null

echo "✅ Capture terminée"
echo ""

# Analyser les paquets capturés
echo "📊 Analyse des paquets RTP..."

# Statistiques générales
echo "=== STATISTIQUES GÉNÉRALES ===" > "$ANALYSIS_FILE"
tshark -r "$PCAP_FILE" -q -z io,stat,0,"udp.port==$AES67_PORT" >> "$ANALYSIS_FILE" 2>/dev/null

# Analyse RTP détaillée
echo "" >> "$ANALYSIS_FILE"
echo "=== ANALYSE RTP DÉTAILLÉE ===" >> "$ANALYSIS_FILE"

# Informations sur les paquets RTP (forcer décodage RTP)
RTP_INFO=$(tshark -r "$PCAP_FILE" -d udp.port==5004,rtp -T fields \
    -e rtp.timestamp \
    -e rtp.seq \
    -e rtp.ssrc \
    -e rtp.p_type \
    -e frame.len \
    -e udp.length \
    -E separator=, 2>/dev/null)

if [ ! -z "$RTP_INFO" ]; then
    echo "Paquets RTP détectés:" >> "$ANALYSIS_FILE"
    echo "$RTP_INFO" | head -20 >> "$ANALYSIS_FILE"
    
    # Compter les paquets
    PACKET_COUNT=$(echo "$RTP_INFO" | wc -l)
    echo "" >> "$ANALYSIS_FILE"
    echo "Nombre total de paquets RTP: $PACKET_COUNT" >> "$ANALYSIS_FILE"
    
    # Analyser les payload types
    echo "" >> "$ANALYSIS_FILE"
    echo "Payload Types détectés:" >> "$ANALYSIS_FILE"
    echo "$RTP_INFO" | cut -d',' -f4 | sort | uniq -c >> "$ANALYSIS_FILE"
    
    # Analyser les tailles de paquets
    echo "" >> "$ANALYSIS_FILE"
    echo "Tailles de paquets (bytes):" >> "$ANALYSIS_FILE"
    echo "$RTP_INFO" | cut -d',' -f5 | sort -n | uniq -c >> "$ANALYSIS_FILE"
    
else
    echo "❌ Aucun paquet RTP détecté" >> "$ANALYSIS_FILE"
fi

# Analyse des erreurs
echo "" >> "$ANALYSIS_FILE"
echo "=== DIAGNOSTIC D'ERREURS ===" >> "$ANALYSIS_FILE"

# Vérifier les erreurs UDP
UDP_ERRORS=$(tshark -r "$PCAP_FILE" -Y "udp.port==$AES67_PORT" -T fields \
    -e frame.time_relative \
    -e udp.checksum_bad \
    -E separator=, 2>/dev/null | grep -v ",,")

if [ ! -z "$UDP_ERRORS" ]; then
    echo "Erreurs UDP détectées:" >> "$ANALYSIS_FILE"
    echo "$UDP_ERRORS" >> "$ANALYSIS_FILE"
else
    echo "✅ Aucune erreur UDP détectée" >> "$ANALYSIS_FILE"
fi

# Afficher les résultats
echo "📋 Résultats de l'analyse:"
echo "=========================="
cat "$ANALYSIS_FILE"

echo ""
echo "🔍 Diagnostic détaillé:"

# Vérifier la conformité AES67
echo ""
echo "🎯 Conformité AES67:"

if grep -q "Payload Types détectés" "$ANALYSIS_FILE"; then
    PAYLOAD_TYPES=$(grep -A 10 "Payload Types détectés" "$ANALYSIS_FILE" | grep -E "[0-9]+" | head -5)
    
    if echo "$PAYLOAD_TYPES" | grep -q "10"; then
        echo "✅ Payload Type 10 (PCM 16-bit) détecté"
    else
        echo "❌ Payload Type 10 manquant"
    fi
    
    if echo "$PAYLOAD_TYPES" | grep -q "96"; then
        echo "✅ Payload Type 96 (PCM 24-bit) détecté"
    else
        echo "⚠️  Payload Type 96 non détecté (optionnel)"
    fi
else
    echo "❌ Aucun payload type détecté"
fi

# Vérifier la régularité des paquets
if [ $PACKET_COUNT -gt 0 ]; then
    echo ""
    echo "📈 Analyse de la régularité:"
    
    if [ $PACKET_COUNT -gt 10 ]; then
        echo "✅ Nombre de paquets suffisant pour l'analyse"
        
        # Calculer l'intervalle moyen (approximatif)
        INTERVAL_MS=$((CAPTURE_DURATION * 1000 / PACKET_COUNT))
        echo "   Intervalle moyen: ~${INTERVAL_MS}ms entre paquets"
        
        if [ $INTERVAL_MS -lt 50 ]; then
            echo "✅ Fréquence de paquets appropriée pour AES67"
        else
            echo "⚠️  Fréquence de paquets faible - possible problème de timing"
        fi
    else
        echo "⚠️  Peu de paquets détectés - possible problème de transmission"
    fi
else
    echo "❌ Aucun paquet RTP - problème de transmission"
fi

echo ""
echo "📁 Fichiers générés:"
echo "  - Capture: $PCAP_FILE"
echo "  - Analyse: $ANALYSIS_FILE"
echo ""
echo "🎯 Prochaines étapes:"
echo "  - Ouvrir $PCAP_FILE dans Wireshark pour analyse visuelle"
echo "  - Vérifier les logs BUTT pour les erreurs AES67"
echo "  - Tester avec un récepteur AES67 compatible" 