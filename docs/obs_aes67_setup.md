# 🎬 Configuration OBS pour AES67 - BUTT Enhanced

## 📋 Objectif
Configurer OBS Studio pour recevoir directement le flux audio AES67 de BUTT avec la meilleure qualité possible.

## 🛠️ Méthode 1: Plugin OBS avec VLC Source

### Étape 1: Installation des prérequis
```bash
# Installer VLC (si pas déjà fait)
brew install --cask vlc

# Vérifier la version d'OBS (minimum 28.0)
open -a "OBS Studio"
```

### Étape 2: Configuration dans OBS
1. **Ouvrir OBS Studio**
2. **Ajouter une Source** → **VLC Video Source**
3. **Créer nouvelle source** : "BUTT AES67 Audio"
4. **Paramètres** :
   - **Playlist** : Ajouter un élément
   - **URL** : `rtp://@239.69.145.58:5004`
   - **Cocher** : "Loop Playlist"
   - **Décocher** : "Shutdown source when not visible"

### Étape 3: Optimisation Audio
1. **Clic droit** sur la source → **Filtres**
2. **Ajouter** → **Gain** (ajuster le niveau si nécessaire)
3. **Ajouter** → **Compressor** (optionnel, pour égaliser)

## 🛠️ Méthode 2: Media Source (Plus direct)

### Configuration
1. **Ajouter une Source** → **Media Source**
2. **Paramètres** :
   - **Décocher** : "Local File"
   - **Input** : `rtp://239.69.145.58:5004`
   - **Input Format** : `rtp`
   - **Cocher** : "Loop"
   - **Cocher** : "Restart playback when source becomes active"

## 🛠️ Méthode 3: Via FFmpeg (Avancée)

### Créer un script de bridge
```bash
#!/bin/bash
# obs_aes67_bridge.sh

FFmpeg_OUTPUT_PORT="8888"
AES67_IP="239.69.145.58"
AES67_PORT="5004"

echo "🎵 Bridge AES67 → OBS via FFmpeg"
echo "================================="
echo "📡 Source: $AES67_IP:$AES67_PORT"
echo "🎬 OBS URL: http://localhost:$FFmpeg_OUTPUT_PORT"

ffmpeg -f rtp -i "rtp://$AES67_IP:$AES67_PORT" \
       -acodec pcm_s16le \
       -ar 48000 \
       -ac 2 \
       -f wav \
       -listen 1 \
       "http://localhost:$FFmpeg_OUTPUT_PORT"
```

### Configuration OBS
1. **Media Source** → **Input** : `http://localhost:8888`

## 📊 Paramètres Audio Recommandés OBS

### Audio Settings
- **Sample Rate** : 48000 Hz
- **Channels** : Stereo
- **Global Audio Devices** : Désactiver si utilisation exclusive AES67

### Advanced Audio Properties
- **AES67 Source** :
  - **Audio Monitoring** : Monitor and Output
  - **Sync Offset** : 0ms (ajuster si décalage)
  - **Audio Filters** : Noise Gate + Compressor si nécessaire

## 🔧 Diagnostic OBS

### Vérifications
1. **Stats OBS** (Affichage → Stats) :
   - Dropped frames audio : 0%
   - Audio latency < 50ms

2. **Audio Mixer** :
   - Signal audio visible sur les VU-mètres
   - Pas de clipping (rouge)
   - Niveau optimal : -12dB à -6dB

### Dépannage
- **Pas d'audio** : Vérifier le multicast route
- **Audio haché** : Réduire la qualité ou augmenter buffer
- **Latence** : Ajuster "Sync Offset" dans Advanced Audio

## 🎯 Test de Validation

### Script de test
```bash
#!/bin/bash
echo "🎬 Test Audio OBS + AES67"
echo "========================="

# 1. Vérifier que BUTT transmet
echo "📡 Test transmission BUTT..."
timeout 5s tcpdump -i en0 -c 5 dst host 239.69.145.58 and port 5004

# 2. Test réception OBS
echo "📺 Test dans OBS..."
echo "   1. Vérifiez le signal dans Audio Mixer"
echo "   2. Lancez un enregistrement test de 10s"
echo "   3. Vérifiez la qualité audio"

# 3. Comparaison
echo "🔍 Comparez avec l'audio source BUTT"
echo "   - Latence perceptible ?"
echo "   - Qualité identique ?"
echo "   - Pas d'artefacts ?"
```

## 📈 Optimisations Avancées

### Réduction de Latence
1. **OBS** : Settings → Advanced → Audio → Audio Monitoring Device
2. **Buffer size** : Le plus petit possible (64-128 samples)
3. **Sample rate** : Correspondant exactement (48000 Hz)

### Qualité Maximum
1. **BUTT** : Output quality 24-bit si supporté
2. **OBS** : Recording → Audio Encoder → PCM ou FLAC
3. **Network** : Interface Gigabit pour éviter congestion

## ✅ Validation Finale

### Checklist
- [ ] Audio visible dans OBS Mixer
- [ ] Pas de dropouts ou coupures
- [ ] Latence < 100ms (idéal < 50ms)
- [ ] Qualité audio identique à la source
- [ ] Pas d'artefacts de compression
- [ ] Synchronisation vidéo correcte (si applicable)

### Métriques de Succès
- **Latence totale** : < 100ms (BUTT → AES67 → OBS)
- **Qualité** : Transparent vs source directe
- **Stabilité** : Aucun dropout sur 1h de test
- **CPU usage** : < 5% additionnel dans OBS

---

💡 **Conseil** : Pour un usage professionnel, testez d'abord avec tous les paramètres puis optimisez progressivement la latence et la qualité selon vos besoins spécifiques. 