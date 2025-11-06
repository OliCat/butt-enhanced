#!/bin/bash
# Script pour analyser les fichiers BUTT sur le Mac Studio

echo "=== Analyse des fichiers BUTT ==="
echo ""

BASE_PATH="/Users/ogrieco/stereoTool_testSDK/butt-enhanced"

echo "1. Analyse de aes67_output.cpp:"
echo "=================================="
if [ -f "$BASE_PATH/backup_20250726_215108/aes67_output.cpp" ]; then
    echo ""
    echo "Fonctions dans le fichier:"
    grep -n "^[a-zA-Z].*(" "$BASE_PATH/backup_20250726_215108/aes67_output.cpp" | head -20
    echo ""
    echo "Fonctions qui envoient:"
    grep -n "send\|write\|output\|aes67" "$BASE_PATH/backup_20250726_215108/aes67_output.cpp" -i | head -20
    echo ""
    echo "Références à multicast/UDP:"
    grep -n "multicast\|udp\|UDP\|239.69.145.58\|5004" "$BASE_PATH/backup_20250726_215108/aes67_output.cpp" | head -20
else
    echo "❌ Fichier non trouvé: $BASE_PATH/backup_20250726_215108/aes67_output.cpp"
fi

echo ""
echo "2. Analyse de port_audio.cpp:"
echo "=============================="
if [ -f "$BASE_PATH/src/port_audio.cpp" ]; then
    echo ""
    echo "Fonctions dans le fichier:"
    grep -n "^[a-zA-Z].*(" "$BASE_PATH/src/port_audio.cpp" | head -20
    echo ""
    echo "Références à Stéréotool:"
    grep -n "stereotool\|Stereotool" "$BASE_PATH/src/port_audio.cpp" -i | head -20
    echo ""
    echo "Callbacks audio:"
    grep -n "callback\|Callback\|process\|Process" "$BASE_PATH/src/port_audio.cpp" | head -20
else
    echo "❌ Fichier non trouvé: $BASE_PATH/src/port_audio.cpp"
fi

echo ""
echo "3. Recherche des includes et headers:"
echo "======================================"
echo ""
echo "Headers inclus dans aes67_output.cpp:"
grep -n "^#include" "$BASE_PATH/backup_20250726_215108/aes67_output.cpp" 2>/dev/null | head -20

echo ""
echo "Headers inclus dans port_audio.cpp:"
grep -n "^#include" "$BASE_PATH/src/port_audio.cpp" 2>/dev/null | head -20

echo ""
echo "=== Instructions ==="
echo ""
echo "Notez les informations suivantes:"
echo "  1. Nom de la fonction qui envoie vers AES67"
echo "  2. Paramètres de cette fonction (audio_data, num_frames, etc.)"
echo "  3. Format des données audio (float, int16, sample_rate, channels)"
echo "  4. Point où cette fonction est appelée"
