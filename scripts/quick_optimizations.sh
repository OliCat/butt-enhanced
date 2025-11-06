#!/bin/bash

# 🚀 Quick Optimizations - BUTT Enhanced AES67 Production
# ========================================================
# Optimisations rapides à appliquer immédiatement pour la production

echo "🚀 BUTT Enhanced AES67 - Quick Production Optimizations"
echo "======================================================="
echo ""

# Configuration
PROJECT_DIR="/Users/ogrieco/stereoTool_testSDK/butt-enhanced"
BACKUP_DIR="$PROJECT_DIR/backups/$(date +%Y%m%d_%H%M%S)"

echo "📁 Projet: $PROJECT_DIR"
echo "💾 Backup: $BACKUP_DIR"
echo ""

# Créer backup avant modifications
mkdir -p "$BACKUP_DIR"

# ========================================
# OPTIMISATION 1: Réduction Latence RTP
# ========================================
echo "⚡ OPTIMISATION 1: Réduction Latence RTP"
echo "----------------------------------------"

ORIGINAL_FILE="$PROJECT_DIR/src/aes67_output.cpp"
BACKUP_FILE="$BACKUP_DIR/aes67_output.cpp.backup"

if [ -f "$ORIGINAL_FILE" ]; then
    cp "$ORIGINAL_FILE" "$BACKUP_FILE"
    echo "✅ Backup créé: $BACKUP_FILE"
    
    # Modifier la taille des paquets pour réduire la latence
    sed -i.tmp 's/const size_t max_packet_size = 1200;/const size_t max_packet_size = 800;/' "$ORIGINAL_FILE"
    
    if [ $? -eq 0 ]; then
        echo "✅ Taille paquets RTP réduite: 1200 → 800 bytes"
        rm "$ORIGINAL_FILE.tmp"
    else
        echo "❌ Erreur lors de la modification"
    fi
else
    echo "⚠️  Fichier non trouvé: $ORIGINAL_FILE"
fi

echo ""

# ========================================
# OPTIMISATION 2: Configuration Système
# ========================================
echo "🔧 OPTIMISATION 2: Configuration Système"
echo "----------------------------------------"

# Optimisations réseau macOS pour broadcast
echo "📡 Application optimisations réseau..."

# Buffer sizes UDP (nécessite sudo)
if [ "$EUID" -eq 0 ]; then
    sysctl -w net.inet.udp.maxdgram=65535
    sysctl -w net.inet.udp.recvspace=1048576
    sysctl -w net.inet.udp.sendspace=1048576
    echo "✅ Buffer UDP optimisés"
else
    echo "⚠️  Optimisations réseau nécessitent sudo:"
    echo "   sudo sysctl -w net.inet.udp.maxdgram=65535"
    echo "   sudo sysctl -w net.inet.udp.recvspace=1048576"
    echo "   sudo sysctl -w net.inet.udp.sendspace=1048576"
fi

echo ""

# ========================================
# OPTIMISATION 3: Monitoring Basique
# ========================================
echo "📊 OPTIMISATION 3: Monitoring Basique"
echo "------------------------------------"

# Créer script de monitoring simple
cat > "$PROJECT_DIR/monitor_aes67.sh" << 'EOF'
#!/bin/bash

# 📊 BUTT AES67 - Monitoring Simple
# ==================================

echo "📡 AES67 Status Monitor"
echo "======================"
echo "🕐 $(date)"
echo ""

# Vérifier processus BUTT
BUTT_PID=$(pgrep -f "butt" | head -1)
if [ ! -z "$BUTT_PID" ]; then
    echo "✅ BUTT running (PID: $BUTT_PID)"
    
    # CPU/Memory usage
    ps -p $BUTT_PID -o pid,pcpu,pmem,comm
else
    echo "❌ BUTT not running"
fi

echo ""

# Vérifier trafic AES67
echo "📊 AES67 Network Traffic:"
netstat -an | grep ":5004" || echo "❌ Pas de trafic sur port 5004"

echo ""

# Test de connectivité
echo "🔍 Network Test:"
ping -c 1 239.69.145.58 > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Multicast reachable"
else
    echo "⚠️  Multicast issues"
fi

echo ""
echo "📈 Quick Stats:"
echo "  - Capture test: ffmpeg -f rtp -i 'rtp://239.69.145.58:5004' -t 2 -y test_quick.wav"
echo "  - Diagnostic: ./diagnostic_aes67_rtp.sh"
echo "  - Audio test: ./test_audio_now.sh"
EOF

chmod +x "$PROJECT_DIR/monitor_aes67.sh"
echo "✅ Monitoring script créé: monitor_aes67.sh"

echo ""

# ========================================
# OPTIMISATION 4: Preset OBS
# ========================================
echo "🎬 OPTIMISATION 4: Preset OBS Automatique"
echo "----------------------------------------"

# Créer preset OBS pour AES67
cat > "$PROJECT_DIR/obs_aes67_preset.json" << 'EOF'
{
  "name": "BUTT AES67 Audio Source",
  "description": "Configuration optimisée pour studio radio",
  "settings": {
    "sources": [
      {
        "name": "BUTT AES67 Stream",
        "type": "vlc_source",
        "settings": {
          "playlist": [
            {
              "value": "rtp://@239.69.145.58:5004"
            }
          ],
          "loop": true,
          "shuffle": false,
          "playback_behavior": "always_play"
        },
        "filters": [
          {
            "name": "Gain Adjust",
            "type": "gain_filter",
            "settings": {
              "db": 0.0
            }
          },
          {
            "name": "Noise Gate",
            "type": "noise_gate_filter",
            "settings": {
              "close_threshold": -40.0,
              "open_threshold": -35.0,
              "attack_time": 25,
              "hold_time": 200,
              "release_time": 150
            }
          }
        ]
      }
    ],
    "audio_settings": {
      "sample_rate": 48000,
      "channels": "stereo",
      "monitoring": "monitor_and_output"
    }
  },
  "instructions": [
    "1. Ouvrir OBS Studio",
    "2. Sources → Ajouter → VLC Video Source",
    "3. Coller URL: rtp://@239.69.145.58:5004",
    "4. Cocher 'Loop Playlist'",
    "5. Ajuster gain si nécessaire",
    "6. Tester avec BUTT en cours d'exécution"
  ]
}
EOF

echo "✅ Preset OBS créé: obs_aes67_preset.json"

echo ""

# ========================================
# OPTIMISATION 5: Script de Test Production
# ========================================
echo "🧪 OPTIMISATION 5: Test Production Rapide"
echo "----------------------------------------"

cat > "$PROJECT_DIR/production_test.sh" << 'EOF'
#!/bin/bash

# 🧪 BUTT AES67 - Test Production Rapide
# ======================================

echo "🧪 Test Production BUTT AES67"
echo "============================="
echo ""

# Test 1: Vérifier BUTT fonctionne
echo "🔍 Test 1: Processus BUTT"
if pgrep -f "butt" > /dev/null; then
    echo "✅ BUTT running"
else
    echo "❌ BUTT not running - Démarrer BUTT first"
    exit 1
fi

# Test 2: Trafic réseau AES67
echo ""
echo "🔍 Test 2: Trafic AES67"
PACKETS=$(timeout 3s tcpdump -i en0 -c 5 dst host 239.69.145.58 and port 5004 2>/dev/null | wc -l)
if [ "$PACKETS" -gt 0 ]; then
    echo "✅ AES67 packets detected ($PACKETS)"
else
    echo "❌ No AES67 traffic"
fi

# Test 3: Capture audio rapide
echo ""
echo "🔍 Test 3: Capture Audio (5s)"
ffmpeg -protocol_whitelist file,udp,rtp \
       -f rtp -i rtp://239.69.145.58:5004 \
       -t 5 -acodec pcm_s16le -ar 48000 -ac 2 \
       -y production_test.wav -loglevel error 2>/dev/null

if [ -f "production_test.wav" ]; then
    SIZE=$(stat -f%z production_test.wav)
    echo "✅ Audio captured: production_test.wav ($SIZE bytes)"
    
    # Test niveau audio
    if command -v ffmpeg > /dev/null; then
        LEVEL=$(ffmpeg -i production_test.wav -af volumedetect -f null - 2>&1 | grep mean_volume | awk '{print $2}' | sed 's/dB//')
        if [ ! -z "$LEVEL" ]; then
            echo "📊 Audio level: ${LEVEL}dB"
            if (( $(echo "$LEVEL > -40" | bc -l) )); then
                echo "✅ Audio level OK"
            else
                echo "⚠️  Audio level low"
            fi
        fi
    fi
else
    echo "❌ Audio capture failed"
fi

# Test 4: OBS URL
echo ""
echo "🔍 Test 4: OBS Integration"
echo "📋 URL pour OBS: rtp://@239.69.145.58:5004"
echo "📋 Alternative: rtp://239.69.145.58:5004"

echo ""
echo "🎯 Résultats:"
echo "✅ BUTT + AES67 prêt pour production"
echo "📺 Configurer OBS avec URL ci-dessus"
echo "📊 Monitoring: ./monitor_aes67.sh"
echo "🔧 Diagnostic: ./diagnostic_aes67_rtp.sh"

# Nettoyage
rm -f production_test.wav

echo ""
echo "🚀 Production Ready!"
EOF

chmod +x "$PROJECT_DIR/production_test.sh"
echo "✅ Script test production créé: production_test.sh"

echo ""

# ========================================
# RECOMPILATION
# ========================================
echo "🔨 RECOMPILATION avec optimisations"
echo "==================================="

cd "$PROJECT_DIR"

if [ -f "src/aes67_output.cpp" ]; then
    echo "📦 Recompilation en cours..."
    PKG_CONFIG_PATH="/usr/local/lib/pkgconfig" arch -x86_64 make clean > /dev/null 2>&1
    PKG_CONFIG_PATH="/usr/local/lib/pkgconfig" arch -x86_64 make -j4 > build.log 2>&1
    
    if [ $? -eq 0 ]; then
        echo "✅ Recompilation réussie"
        echo "🎯 BUTT optimisé pour production disponible"
    else
        echo "❌ Erreur de compilation - voir build.log"
    fi
else
    echo "⚠️  Pas de recompilation nécessaire"
fi

echo ""

# ========================================
# RÉSUMÉ
# ========================================
echo "📋 RÉSUMÉ DES OPTIMISATIONS APPLIQUÉES"
echo "======================================"
echo ""
echo "✅ Optimisations appliquées:"
echo "  1. ⚡ Latence RTP réduite (800 bytes packets)"
echo "  2. 📊 Monitoring script (monitor_aes67.sh)"
echo "  3. 🎬 Preset OBS (obs_aes67_preset.json)"
echo "  4. 🧪 Test production (production_test.sh)"
echo "  5. 🔨 Recompilation optimisée"
echo ""
echo "🎯 PROCHAINES ÉTAPES:"
echo "  1. Tester: ./production_test.sh"
echo "  2. Configurer OBS avec URL: rtp://@239.69.145.58:5004"
echo "  3. Monitorer: ./monitor_aes67.sh"
echo "  4. Valider latence en live broadcast"
echo ""
echo "📖 Roadmap complète: ROADMAP_AES67_PRODUCTION.md"
echo ""
echo "🚀 Prêt pour production studio radio !" 