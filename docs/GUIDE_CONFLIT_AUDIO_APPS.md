# 🎵 Guide - Résolution Conflits Audio BUTT Enhanced

## 🚨 **Problème : Qobuz Interface Figée avec BUTT**

### **Diagnostic Initial**
- ✅ **BUTT fonctionne** : AES67 actif, audio traité
- ❌ **Qobuz figé** : Interface non-responsive 
- 🎯 **Cause** : Conflit ressources Core Audio macOS

---

## 🔍 **ANALYSE TECHNIQUE**

### **1. Core Audio - Ressource Partagée**
```bash
# BUTT utilise Core Audio via :
- PortAudio → Core Audio
- StereoTool → Audio processing 
- AES67 → Network audio output

# Qobuz utilise Core Audio via :
- Electron → Web Audio API → Core Audio
- Audio streaming → Hardware output
```

### **2. Types de Conflits**

#### **Conflit A : Périphérique Audio Exclusif**
- BUTT prend l'accès exclusif au device audio
- Qobuz ne peut plus accéder au hardware
- **Symptôme** : Interface figée à l'ouverture

#### **Conflit B : Core Audio HAL Overload**  
- Trop de connexions Core Audio simultanées
- Buffer audio overflow/underflow
- **Symptôme** : Interface ralentie/figée

#### **Conflit C : Thread Priority Conflicts**
- BUTT utilise threads haute priorité pour audio
- Qobuz (Electron) devient starved
- **Symptôme** : Interface devient non-responsive

#### **Conflit D : Sample Rate Conflicts**
- BUTT force un sample rate (48kHz)
- Qobuz essaie un autre rate (44.1kHz) 
- **Symptôme** : Audio distordu ou silence

---

## 🛠️ **SOLUTIONS RAPIDES**

### **Solution 1 : Redémarrer Qobuz (Immédiat)**
```bash
# Forcer quit et redémarrer Qobuz
pkill -f "Qobuz"
sleep 2
open -a Qobuz
```

### **Solution 2 : Sample Rate Unifié**
```bash
# Forcer macOS en 48kHz (match BUTT)
sudo kextunload /System/Library/Extensions/AppleHDA.kext
sudo kextload /System/Library/Extensions/AppleHDA.kext

# Ou dans System Preferences:
# Audio MIDI Setup → Built-in Output → 48000 Hz
```

### **Solution 3 : Device Audio Séparé**
```bash
# Option A: BUTT sur device externe
# - Interface audio USB/Thunderbolt pour BUTT
# - Built-in audio pour Qobuz

# Option B: Virtual Audio Device
# - SoundSource/Loopback/BlackHole
# - Routing séparé par app
```

### **Solution 4 : Configuration BUTT Optimisée**
```bash
# Réduire priorité threads BUTT
# Modifier src/port_audio.cpp buffer sizes
# Limiter usage CPU/mémoire
```

---

## ⚙️ **CONFIGURATION RECOMMANDÉE STUDIO**

### **Setup A : Device Séparé (OPTIMAL)**
```
🎧 BUTT Enhanced:
  ├── Interface audio dédiée (USB/TB)
  ├── StereoTool processing
  └── AES67 output → Réseau

🎵 Qobuz:
  ├── Built-in audio Mac
  ├── Sortie casque/enceintes
  └── Monitoring/référence
```

### **Setup B : Virtual Audio Routing**
```
🔊 BlackHole/Loopback:
  ├── BUTT → Virtual Device 1
  ├── Qobuz → Virtual Device 2  
  ├── Mix → Built-in output
  └── Monitoring indépendant
```

### **Setup C : Workflow Optimisé**
```
📺 Production Live:
  1. Lancer BUTT (priorité haute)
  2. Configurer AES67
  3. Lancer Qobuz APRÈS stabilisation
  4. Monitoring séparé
```

---

## 🧪 **SCRIPTS DE DIAGNOSTIC**

### **Script 1 : Test Conflit Audio**
```bash
#!/bin/bash
# test_audio_conflict.sh

echo "🔍 Diagnostic Conflit Audio BUTT/Qobuz"

# Vérifier processus audio
echo "📊 Processus Audio:"
ps aux | grep -E "(butt|Qobuz|coreaudio)" | grep -v grep

# Sample rate système
echo "📡 Sample Rate Système:"
system_profiler SPAudioDataType | grep -A 2 -B 2 "Sample Rate"

# Core Audio connections
echo "🔗 Connexions Core Audio:"
lsof -c butt | grep -i audio
lsof -c Qobuz | grep -i audio

# CPU usage temps réel
echo "💻 CPU Usage:"
top -l 1 | grep -E "(butt|Qobuz)"
```

### **Script 2 : Restart Qobuz Clean**
```bash
#!/bin/bash
# restart_qobuz_clean.sh

echo "🔄 Redémarrage Clean Qobuz"

# Kill tous les processus Qobuz
pkill -f "Qobuz"
sleep 3

# Vérifier arrêt complet
if pgrep -f "Qobuz" > /dev/null; then
    echo "⚠️ Force kill nécessaire"
    pkill -9 -f "Qobuz"
    sleep 2
fi

# Nettoyer cache audio si besoin
sudo pkill -HUP coreaudiod

# Redémarrer Qobuz
echo "🚀 Redémarrage Qobuz..."
open -a Qobuz

echo "✅ Qobuz redémarré - tester interface"
```

### **Script 3 : Optimisation BUTT**
```bash
#!/bin/bash
# optimize_butt_audio.sh

echo "⚡ Optimisation BUTT pour coexistence"

# Réduire priorité processus BUTT
PID=$(pgrep -f "butt")
if [ ! -z "$PID" ]; then
    sudo renice +5 $PID
    echo "📉 Priorité BUTT réduite"
fi

# Buffer audio optimisé (nécessite rebuild)
echo "🔧 Pour optimisation permanente:"
echo "  - Modifier BUFFER_SIZE dans src/port_audio.cpp"
echo "  - Réduire pa_frames de 512 à 256"
echo "  - Recompiler BUTT"
```

---

## 📋 **CHECKLIST PRODUCTION**

### **Avant Session Live**
- [ ] **Audio device routing** configuré
- [ ] **BUTT lancé et stabilisé** (AES67 actif)
- [ ] **Qobuz testé** (interface responsive)
- [ ] **Sample rates alignés** (48kHz partout)
- [ ] **Monitoring audio** indépendant
- [ ] **Scripts de fallback** prêts

### **Pendant Session**
- [ ] **Monitor CPU usage** BUTT < 10%
- [ ] **Interface Qobuz** reste responsive
- [ ] **Pas de dropouts** audio
- [ ] **AES67 stable** vers OBS
- [ ] **Scripts diagnostic** en standby

### **Résolution Urgente**
```bash
# En cas de problème pendant live:
./restart_qobuz_clean.sh     # Redémarrage rapide
./test_audio_conflict.sh     # Diagnostic immédiat
sudo pkill -HUP coreaudiod   # Reset Core Audio
```

---

## 🎯 **RECOMMANDATIONS FINALES**

### **Court Terme (Cette Semaine)**
1. **Tester restart script** Qobuz
2. **Unifier sample rates** à 48kHz
3. **Monitor usage CPU** BUTT en continu
4. **Alternative routing** audio si possible

### **Long Terme (Roadmap)**
1. **Interface audio dédiée** pour BUTT
2. **Virtual audio routing** professionnel
3. **Buffer optimization** dans BUTT code
4. **Thread priority tuning** 

### **Solution Ultime**
```
🏆 SETUP PROFESSIONNEL OPTIMAL:
┌─────────────────────────────────────┐
│ 🎵 SOURCES AUDIO                   │
├─────────────────────────────────────┤
│ Micro/Line → Interface USB/TB       │
│             ↓                       │ 
│ BUTT + StereoTool + AES67          │
│             ↓                       │
│ Réseau → OBS Studio                │
├─────────────────────────────────────┤
│ 🎧 MONITORING                      │ 
├─────────────────────────────────────┤
│ Qobuz → Built-in Audio → Casque   │
│ Référence musicale indépendante    │
└─────────────────────────────────────┘
```

---

> **Note Importante** : Ce conflit est **normal** dans les studios audio. La solution pérenne est le **routing séparé** des applications audio.

**Dernière mise à jour** : 26 juillet 2024 