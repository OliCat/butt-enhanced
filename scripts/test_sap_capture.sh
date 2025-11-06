#!/bin/bash

# Test de capture des annonces SAP
# Usage: ./test_sap_capture.sh

echo "=== Test Capture SAP ==="
echo "📡 Capture des annonces SAP sur 224.2.127.254:9875"
echo ""

# Créer un dossier pour les captures
mkdir -p sap_captures

# Nom des fichiers de capture
CAPTURE_FILE="sap_captures/sap_announcements.pcap"
ANALYSIS_FILE="sap_captures/sap_analysis.txt"

echo "🎯 Démarrage de la capture SAP..."
echo "⏱️  Capture pendant 10 secondes..."

# Capturer les paquets SAP pendant 10 secondes
sudo tcpdump -i any -w "$CAPTURE_FILE" "udp port 9875" &
TCPDUMP_PID=$!

# Attendre 2 secondes pour que tcpdump démarre
sleep 2

echo "🚀 Lancement du test SAP..."
# Lancer le test SAP en arrière-plan
./test_sap > /dev/null 2>&1 &
SAP_PID=$!

# Attendre 8 secondes
sleep 8

# Arrêter la capture
kill $TCPDUMP_PID 2>/dev/null
wait $TCPDUMP_PID 2>/dev/null

# Arrêter le test SAP
kill $SAP_PID 2>/dev/null
wait $SAP_PID 2>/dev/null

echo "✅ Capture terminée"
echo ""

# Analyser les paquets capturés
echo "🔍 Analyse des paquets SAP..."

if [ -f "$CAPTURE_FILE" ]; then
    # Compter le nombre de paquets
    PACKET_COUNT=$(tcpdump -r "$CAPTURE_FILE" 2>/dev/null | wc -l)
    
    echo "📊 Statistiques de capture:"
    echo "   - Fichier: $CAPTURE_FILE"
    echo "   - Paquets capturés: $PACKET_COUNT"
    echo ""
    
    # Analyser avec tshark si disponible
    if command -v tshark >/dev/null 2>&1; then
        echo "🔬 Analyse détaillée avec tshark:"
        tshark -r "$CAPTURE_FILE" -T fields \
            -e frame.time \
            -e ip.src \
            -e ip.dst \
            -e udp.length \
            -e sap.msg_type \
            -e sap.hash \
            -e sap.auth_len \
            -e sap.payload 2>/dev/null | head -10 > "$ANALYSIS_FILE"
        
        echo "📄 Résultats détaillés:"
        cat "$ANALYSIS_FILE"
        echo ""
    else
        echo "⚠️  tshark non disponible - analyse basique:"
        tcpdump -r "$CAPTURE_FILE" -A 2>/dev/null | head -20
        echo ""
    fi
    
    # Vérifier la présence de paquets SAP
    if [ $PACKET_COUNT -gt 0 ]; then
        echo "✅ SUCCÈS: Paquets SAP détectés"
        echo "🎯 Les annonces SAP sont envoyées correctement"
        echo "📡 Les récepteurs AES67 peuvent maintenant découvrir le flux"
    else
        echo "❌ ÉCHEC: Aucun paquet SAP détecté"
        echo "🔍 Vérifiez les paramètres réseau et les permissions"
    fi
    
else
    echo "❌ ERREUR: Fichier de capture non trouvé"
fi

echo ""
echo "📁 Fichiers générés:"
echo "   - Capture: $CAPTURE_FILE"
echo "   - Analyse: $ANALYSIS_FILE"
echo ""
echo "🎯 Pour ouvrir dans Wireshark:"
echo "   wireshark $CAPTURE_FILE"
echo ""
echo "=== Test terminé ===" 