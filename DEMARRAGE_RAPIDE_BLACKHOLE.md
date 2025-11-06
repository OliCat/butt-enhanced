# 🚀 Démarrage rapide - BUTT avec BlackHole

## Installation (3 étapes)

### 1️⃣ Installer BlackHole
```bash
brew install blackhole-2ch
```

### 2️⃣ Installer BUTT
```bash
sudo cp -R /Users/ogrieco/stereoTool_testSDK/butt-enhanced/build/BUTT.app /Applications/
```

### 3️⃣ Lancer BUTT
```bash
open /Applications/BUTT.app
```

---

## ✅ Vérification

Au démarrage de BUTT, vous devriez voir dans les logs :
```
✅ BlackHole initialisé pour Whisper Streaming (sample_rate: 48000, channels: 2)
```

Si BlackHole n'est pas installé :
```
⚠️  BlackHole non initialisé, Whisper Streaming ne fonctionnera pas
    Installez BlackHole avec: brew install blackhole-2ch
```

---

## 🎙️ Utilisation avec Whisper Streaming

```bash
# Configurer Whisper Streaming pour capturer depuis BlackHole
export WHISPER_AUDIO_SOURCE=blackhole

# Lancer Whisper Streaming
python whisper_streaming_service.py
```

---

## 🔍 Test rapide

Vérifier que BlackHole est disponible :
```bash
ffmpeg -f avfoundation -list_devices true -i ""
```

Vous devriez voir "BlackHole 2ch" dans la liste.

---

## 📊 Architecture

```
CAPITOL IP Console (USB)
    ↓
BUTT
    ↓
StereoTool SDK PRO
    ↓
    ├── → AES67 (239.69.145.58:5004) → Machine OBS
    └── → BlackHole 2ch → Whisper Streaming
```

---

## 🛠️ Dépannage express

### BlackHole non détecté
```bash
# Réinstaller
brew reinstall blackhole-2ch

# Vérifier
brew list blackhole-2ch
```

### Pas de son dans Whisper
```bash
# Tester directement BlackHole
ffplay -f avfoundation -i ":BlackHole 2ch"
```

### Recompiler BUTT
```bash
cd /Users/ogrieco/stereoTool_testSDK/butt-enhanced
make clean
make -j4
./build_macos_bundle.sh
```

---

## 📚 Documentation complète

- `INTEGRATION_BLACKHOLE_COMPLETE.md` - Documentation complète
- `integration_blackhole_butt/INTEGRATION_REUSSIE.md` - Résumé de l'intégration
- `integration_blackhole_butt/README.md` - Documentation d'origine

---

## ✨ C'est tout !

BUTT est maintenant configuré pour envoyer l'audio traité par StereoTool simultanément vers :
- **AES67** pour OBS
- **BlackHole** pour Whisper Streaming

**Aucune configuration supplémentaire nécessaire !** 🎉

