#!/bin/bash

# 🎵 Capture Audio AES67 Optimisée - BUTT Enhanced
# ================================================

echo "🎵 Capture Audio AES67 - Méthodes Multiples"
echo "============================================="

# Configuration
AES67_IP="239.69.145.58"
AES67_PORT="5004" 
DURATION="30"  # 30 secondes pour un bon test

echo "📡 Configuration détectée:"
echo "  - IP: $AES67_IP"
echo "  - Port: $AES67_PORT"
echo "  - Format: PCM 24-bit, 48kHz, Stéréo"
echo "  - Payload Type: 96"
echo ""

# ========================================
# MÉTHODE 1: FFmpeg avec SDP (Recommandée)
# ========================================
echo "🎯 MÉTHODE 1: FFmpeg avec description SDP"
echo ""

# Créer un fichier SDP pour FFmpeg
cat > aes67_stream.sdp << EOF
v=0
o=- 0 0 IN IP4 $AES67_IP
s=BUTT AES67 Stream
c=IN IP4 $AES67_IP/32
t=0 0
m=audio $AES67_PORT RTP/AVP 96
a=rtpmap:96 L24/48000/2
a=recvonly
EOF

echo "📁 Fichier SDP créé: aes67_stream.sdp"
echo ""

function capture_with_ffmpeg() {
    local output_file="$1"
    local format="$2"
    local desc="$3"
    
    echo "🎵 Capture avec FFmpeg ($desc)..."
    echo "   Durée: ${DURATION}s"
    echo "   Fichier: $output_file"
    
    ffmpeg -protocol_whitelist file,udp,rtp \
           -i aes67_stream.sdp \
           -t $DURATION \
           -acodec $format \
           -ar 48000 \
           -ac 2 \
           -y "$output_file" \
           -loglevel warning -stats
    
    if [ $? -eq 0 ]; then
        echo "✅ Capture réussie: $output_file"
        analyze_audio "$output_file"
    else
        echo "❌ Échec de la capture"
    fi
}

# ========================================
# MÉTHODE 2: GStreamer (Alternative)
# ========================================
function capture_with_gstreamer() {
    local output_file="$1"
    
    echo ""
    echo "🎯 MÉTHODE 2: GStreamer"
    echo "🎵 Capture avec GStreamer..."
    
    if command -v gst-launch-1.0 &> /dev/null; then
        gst-launch-1.0 udpsrc port=$AES67_PORT multicast-group=$AES67_IP ! \
            "application/x-rtp,media=(string)audio,payload=(int)96,clock-rate=(int)48000,channels=(int)2" ! \
            rtpL24depay ! \
            audioconvert ! \
            "audio/x-raw,format=S24LE,rate=48000,channels=2" ! \
            wavenc ! \
            filesink location="$output_file" &
        
        GST_PID=$!
        sleep $DURATION
        kill $GST_PID 2>/dev/null
        
        if [ -f "$output_file" ]; then
            echo "✅ Capture GStreamer réussie: $output_file"
            analyze_audio "$output_file"
        fi
    else
        echo "⚠️  GStreamer non installé - Sautez cette méthode"
    fi
}

# ========================================
# ANALYSE AUDIO
# ========================================
function analyze_audio() {
    local file="$1"
    
    echo ""
    echo "📊 Analyse de $file..."
    
    # Informations de base
    if command -v ffprobe &> /dev/null; then
        ffprobe -v quiet -print_format json -show_streams "$file" | jq -r '
            .streams[0] | 
            "  - Format: \(.codec_name)",
            "  - Sample Rate: \(.sample_rate) Hz", 
            "  - Canaux: \(.channels)",
            "  - Bit Depth: \(.bits_per_sample // "N/A") bits",
            "  - Durée: \(.duration)s"
        '
    fi
    
    # Analyse du niveau audio
    if command -v ffmpeg &> /dev/null; then
        echo "  - Analyse du niveau..."
        VOLUME_INFO=$(ffmpeg -i "$file" -af "volumedetect" -f null - 2>&1 | grep -E "(mean_volume|max_volume)")
        echo "$VOLUME_INFO" | sed 's/^/    /'
        
        # Vérifier si audio présent
        MEAN_VOL=$(echo "$VOLUME_INFO" | grep "mean_volume" | awk '{print $2}' | sed 's/dB//')
        if [ ! -z "$MEAN_VOL" ] && (( $(echo "$MEAN_VOL > -50" | bc -l) )); then
            echo "  ✅ Audio détecté - Niveau correct"
        else
            echo "  ⚠️  Audio faible ou absent"
        fi
    fi
    
    echo ""
}

# ========================================
# LECTURE AUDIO
# ========================================
function play_audio() {
    local file="$1"
    
    echo "🔊 Test de lecture: $file"
    echo "   (Appuyez sur Ctrl+C pour arrêter)"
    
    if command -v afplay &> /dev/null; then
        # macOS
        afplay "$file"
    elif command -v aplay &> /dev/null; then
        # Linux
        aplay "$file"
    elif command -v ffplay &> /dev/null; then
        # FFmpeg player
        ffplay -nodisp -autoexit "$file"
    else
        echo "⚠️  Aucun lecteur audio trouvé"
        echo "   Ouvrez $file manuellement dans votre lecteur audio"
    fi
}

# ========================================
# EXÉCUTION PRINCIPALE
# ========================================

echo "🎤 Vérifiez que BUTT fonctionne et transmet AES67..."
echo "   Appuyez sur Entrée pour commencer les captures..."
read -r

# Capture PCM 24-bit (natif)
capture_with_ffmpeg "aes67_24bit.wav" "pcm_s24le" "PCM 24-bit natif"

echo ""
echo "─────────────────────────────────────────────"

# Capture PCM 16-bit (compatible)
capture_with_ffmpeg "aes67_16bit.wav" "pcm_s16le" "PCM 16-bit compatible"

# Optionnel: GStreamer
if command -v gst-launch-1.0 &> /dev/null; then
    echo ""
    echo "─────────────────────────────────────────────"
    capture_with_gstreamer "aes67_gstreamer.wav"
fi

# ========================================
# TESTS D'ÉCOUTE
# ========================================
echo ""
echo "🎧 Tests d'écoute disponibles:"
echo "================================"

for file in aes67_24bit.wav aes67_16bit.wav aes67_gstreamer.wav; do
    if [ -f "$file" ]; then
        echo ""
        echo "Fichier: $file"
        echo "Voulez-vous l'écouter ? (o/n)"
        read -r response
        
        if [[ "$response" =~ ^[Oo]$ ]]; then
            play_audio "$file"
        fi
    fi
done

echo ""
echo "📁 Fichiers générés:"
ls -lh aes67_*.wav 2>/dev/null | awk '{print "  - " $9 " (" $5 ")"}'

echo ""
echo "🎯 Recommandations:"
echo "  - Utilisez aes67_24bit.wav pour la meilleure qualité"
echo "  - Comparez avec l'audio original de BUTT"  
echo "  - Ouvrez dans Audacity/Logic/Pro Tools pour analyse détaillée"
echo "  - Vérifiez la synchronisation et les artefacts"

# Nettoyage
rm -f aes67_stream.sdp

echo ""
echo "✅ Test de capture terminé !" 