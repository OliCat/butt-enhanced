# 📚 Documentation Complète - BUTT Enhanced

**Version**: 1.45.0-Enhanced  
**Date**: Janvier 2025  
**Plateforme**: macOS (Apple Silicon & Intel)

---

## 📋 Table des Matières

1. [Vue d'ensemble](#vue-densemble)
2. [Installation](#installation)
3. [Configuration](#configuration)
4. [Fonctionnalités](#fonctionnalités)
5. [Architecture Technique](#architecture-technique)
6. [Guides d'utilisation](#guides-dutilisation)
7. [Dépannage](#dépannage)
8. [Développement](#développement)

---

## 🎯 Vue d'ensemble

BUTT Enhanced est une version améliorée de BUTT (Broadcast Using This Tool) développée pour la communauté des radios libres. Cette version ajoute des fonctionnalités professionnelles pour la diffusion audio.

### Fonctionnalités principales

- ✅ **AES67 Audio-over-IP** : Diffusion audio professionnelle sur réseau
- ✅ **BlackHole Output** : Sortie audio virtuelle pour Whisper AI et autres applications
- ✅ **StereoTool SDK** : Traitement audio professionnel (optionnel)
- ✅ **Core Audio** : Support natif macOS avec gestion avancée des périphériques

### Architecture

```
Périphérique Audio USB (ex: CAPITOL IP)
    ↓
BUTT Enhanced
    ↓
StereoTool SDK (optionnel)
    ↓
    ├── → AES67 (239.69.145.58:5004) → Machine OBS
    └── → BlackHole 2ch → Whisper Streaming / Applications
```

---

## 🚀 Installation

### Prérequis

- macOS 11.0 ou supérieur
- Homebrew
- Xcode Command Line Tools

### Installation des dépendances

```bash
brew install portaudio opus flac lame fltk libvorbis libogg \
             libsamplerate portmidi openssl gettext pkg-config \
             autoconf automake libtool blackhole-2ch
```

### Installation de BlackHole

```bash
brew install blackhole-2ch
```

### Compilation

```bash
# Configuration
./configure

# Compilation
make -j4

# Création du bundle macOS
./build_macos_bundle.sh
```

### Installation du bundle

```bash
sudo cp -R build/BUTT.app /Applications/
```

---

## ⚙️ Configuration

### Configuration AES67

1. Ouvrir BUTT
2. **Settings** → **Audio** → **Advanced Audio Outputs**
3. Activer **AES67 Output**
4. Configurer :
   - **IP Address**: `239.69.145.58` (par défaut)
   - **Port**: `5004` (par défaut)
   - **Sample Rate**: `48000 Hz`
   - **Channels**: `2` (stéréo)
   - **Bit Depth**: `24-bit`
   - **PTP**: Activé (recommandé)
   - **SAP**: Activé (recommandé)

### Configuration BlackHole

BlackHole est **automatiquement initialisé** au démarrage de BUTT. Aucune configuration manuelle nécessaire.

Vérification dans les logs :
```
✅ BlackHole initialisé pour Whisper Streaming (sample_rate: 48000, channels: 2)
```

### Configuration StereoTool (optionnel)

1. Télécharger StereoTool SDK depuis [stereo-tool.com](https://www.stereo-tool.com/)
2. Placer `libStereoTool64.dylib` dans le répertoire du projet
3. Dans BUTT : **Settings** → **StereoTool**
4. Activer **Enable StereoTool Processing**

---

## 🎚️ Fonctionnalités

### AES67 Audio-over-IP

**Standard industriel** pour la diffusion audio sur réseau IP.

#### Caractéristiques

- **Multicast UDP** : Diffusion efficace sur réseau local
- **PTP (Precision Time Protocol)** : Synchronisation temporelle précise
- **SAP (Session Announcement Protocol)** : Découverte automatique
- **Format audio** : PCM 24-bit, 48 kHz, stéréo

#### Utilisation avec OBS

L'intégration avec OBS nécessite une configuration spécifique sur la machine OBS. Voir **[README_AES67_OBS.md](README_AES67_OBS.md)** pour le processus complet.

En résumé :
1. La machine OBS reçoit le flux AES67 multicast via GStreamer
2. Le flux est converti et envoyé vers un sink PulseAudio
3. OBS utilise une source "Monitor of aes67_sink" pour intégrer l'audio

#### Test

```bash
# Écouter le flux AES67 avec ffmpeg
ffmpeg -i udp://239.69.145.58:5004 -f s16le -ar 48000 -ac 2 - | aplay
```

### BlackHole Output

**Sortie audio virtuelle** pour capturer l'audio traité par BUTT.

#### Caractéristiques

- **Initialisation automatique** au démarrage
- **Ring buffer** de 2 secondes pour fluidité
- **Zero-latency** : Pas de délai perceptible
- **Simultané avec AES67** : Les deux sorties fonctionnent en parallèle

#### Utilisation avec Whisper Streaming

```bash
# Configurer Whisper Streaming pour capturer depuis BlackHole
export WHISPER_AUDIO_SOURCE=blackhole

# Lancer Whisper Streaming
python whisper_streaming_service.py
```

#### Test avec ffmpeg

```bash
# Capturer depuis BlackHole
ffmpeg -f avfoundation -i ":BlackHole 2ch" -t 10 test_blackhole.wav

# Écouter en temps réel
ffplay -f avfoundation -i ":BlackHole 2ch"
```

### StereoTool SDK

**Traitement audio professionnel** avec compression, égalisation, et effets.

#### Caractéristiques

- **Bypass on silence** : Désactivation automatique sur silence
- **VU meters** : Pré et post traitement
- **Configuration par preset** : Chargement de presets StereoTool
- **Traitement séparé** : Streaming et enregistrement indépendants

---

## 🏗️ Architecture Technique

### Composants principaux

#### 1. AES67 Output (`src/aes67_output.cpp`)

- **Format RTP** : En-têtes conformes AES67
- **Socket UDP** : Gestion multicast avec TTL
- **Ring buffer** : Gestion asynchrone des données
- **Thread dédié** : Envoi continu sur réseau

#### 2. BlackHole Output (`src/blackhole_output.cpp`)

- **Core Audio** : Utilisation d'AudioUnit HAL
- **Ring buffer** : Buffer de 2 secondes
- **Callback render** : Fonction de rendu asynchrone
- **Gestion automatique** : Détection et initialisation automatique

#### 3. StereoTool Wrapper (`src/stereo_tool.cpp`)

- **SDK Integration** : Interface avec libStereoTool64.dylib
- **Processing pipeline** : Traitement en temps réel
- **Configuration** : Chargement de presets et paramètres

### Flux de données

```
PortAudio Input
    ↓
port_audio.cpp (callback)
    ↓
StereoTool Processing (si activé)
    ↓
    ├── → aes67_output_send() → Réseau UDP
    └── → blackhole_output.sendInterleaved() → Core Audio
```

### Synchronisation

- **Ring buffers** : Gestion des différences de timing
- **Mutex** : Protection thread-safe
- **Callback-based** : Architecture asynchrone

---

## 📖 Guides d'utilisation

### Guide AES67

Voir [README_AES67_OBS.md](README_AES67_OBS.md) pour :
- Configuration complète sur la machine OBS
- Pipeline GStreamer pour réception AES67
- Intégration avec OBS Studio via PulseAudio
- Dashboard de supervision

### Guide BlackHole

Voir `../DEMARRAGE_RAPIDE_BLACKHOLE.md` dans la racine pour :
- Installation BlackHole
- Intégration Whisper Streaming
- Tests et validation

### Guide StereoTool

Voir [STEREOTOOL_SDK_REFERENCE.md](STEREOTOOL_SDK_REFERENCE.md) pour :
- Référence complète du SDK
- Fonctions disponibles
- Exemples d'utilisation

---

## 🔧 Dépannage

### AES67

#### Problème : Pas de connexion

**Solutions** :
1. Vérifier le réseau : `ping 239.69.145.58`
2. Vérifier le firewall : Autoriser UDP port 5004
3. Vérifier les logs : Messages d'erreur dans la console

#### Problème : Audio saccadé

**Solutions** :
1. Vérifier la bande passante réseau
2. Réduire la taille des paquets
3. Désactiver PTP si non nécessaire

### BlackHole

#### Problème : BlackHole non initialisé

**Solutions** :
```bash
# Réinstaller BlackHole
brew reinstall blackhole-2ch

# Vérifier l'installation
brew list blackhole-2ch
```

#### Problème : Son saccadé

**Solutions** :
1. Vérifier les logs : `BlackHole::render` et `BlackHole::send`
2. Vérifier la taille du ring buffer
3. Vérifier la charge CPU

### StereoTool

#### Problème : SDK non chargé

**Solutions** :
1. Vérifier le chemin de `libStereoTool64.dylib`
2. Vérifier les permissions du fichier
3. Vérifier l'architecture (ARM64 vs x86_64)

---

## 💻 Développement

### Structure du code

```
src/
├── aes67_output.cpp/h      # Sortie AES67
├── blackhole_output.cpp/h  # Sortie BlackHole
├── stereo_tool.cpp/h       # Wrapper StereoTool
├── port_audio.cpp          # Pipeline audio principal
└── ...
```

### Compilation debug

```bash
./configure CXXFLAGS="-g -O0 -Wall"
make clean
make -j4
```

### Tests

```bash
# Test AES67
ffmpeg -i udp://239.69.145.58:5004 -f s16le -ar 48000 -ac 2 - | aplay

# Test BlackHole
ffplay -f avfoundation -i ":BlackHole 2ch"
```

### Contribution

Voir [CONTRIBUTING.md](../CONTRIBUTING.md) pour les guidelines de contribution.

---

## 📞 Support

### Issues GitHub

[github.com/VOTRE_ORG/butt-enhanced/issues](https://github.com/VOTRE_ORG/butt-enhanced/issues)

### Documentation

- **README.md** : Vue d'ensemble
- **INSTALLATION.md** : Guide d'installation
- **CONTRIBUTING.md** : Guide de contribution

---

## 📜 Licence

### BUTT Enhanced

**GNU General Public License v2.0** - Voir [LICENSE](../LICENSE)

### StereoTool SDK

**Propriétaire** - Non inclus dans cette distribution  
Téléchargement : [stereo-tool.com](https://www.stereo-tool.com/)

### Dépendances

Voir [LICENSE-DEPENDENCIES.md](../LICENSE-DEPENDENCIES.md)

---

**Dernière mise à jour** : Janvier 2025  
**Version** : 1.45.0-Enhanced

