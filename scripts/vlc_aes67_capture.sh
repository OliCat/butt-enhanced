#!/bin/bash

# 🎵 Capture Audio AES67 avec VLC - Méthode Simple
# =================================================

echo "🎵 Capture AES67 avec VLC"
echo "=========================="

AES67_IP="239.69.145.58"
AES67_PORT="5004"
OUTPUT_FILE="aes67_vlc_capture.wav"

echo "📡 Configuration: $AES67_IP:$AES67_PORT"
echo "📁 Fichier: $OUTPUT_FILE"
echo ""

if ! command -v vlc &> /dev/null; then
    echo "❌ VLC n'est pas installé"
    echo "   Installez-le avec: brew install --cask vlc"
    exit 1
fi

echo "🎤 Démarrage de VLC en mode capture..."
echo "   Durée: 30 secondes"
echo "   Appuyez sur Ctrl+C pour arrêter plus tôt"

# Capturer avec VLC 
vlc --intf dummy \
    --extraintf logger \
    --logger-intf dummy \
    "rtp://@$AES67_IP:$AES67_PORT" \
    --sout "#transcode{acodec=s16l,ab=1536,channels=2,samplerate=48000}:std{access=file,mux=wav,dst=$OUTPUT_FILE}" \
    --run-time 30 \
    vlc://quit

if [ -f "$OUTPUT_FILE" ]; then
    echo ""
    echo "✅ Capture VLC réussie: $OUTPUT_FILE"
    
    # Informations rapides
    echo "📊 Informations:"
    ls -lh "$OUTPUT_FILE" | awk '{print "  - Taille: " $5}'
    
    if command -v ffprobe &> /dev/null; then
        ffprobe -v quiet -show_format -show_streams "$OUTPUT_FILE" | grep -E "(duration|sample_rate|channels)" | sed 's/^/  - /'
    fi
    
    echo ""
    echo "🔊 Lancer la lecture ? (o/n)"
    read -r response
    
    if [[ "$response" =~ ^[Oo]$ ]]; then
        echo "🎧 Lecture en cours..."
        open "$OUTPUT_FILE"  # macOS
    fi
else
    echo "❌ Échec de la capture VLC"
fi

echo ""
echo "✅ Terminé !" 