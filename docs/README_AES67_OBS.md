# 🎚️ Système de récupération AES67 pour OBS

Ce document décrit l’architecture et le fonctionnement du système mis en place pour récupérer un **flux audio multicast AES67** (en L24) émis depuis un encodeur (BUTT modifié avec StereoTool), et l’acheminer jusqu’à **OBS Studio** pour intégration dans un flux vidéo.

## 🎯 Objectif

Permettre à une machine distante (serveur OBS) de :
- recevoir un flux AES67 multicast L24,
- le convertir et le rendre accessible à OBS via PipeWire/PulseAudio,
- superviser le flux (présence réseau, audio réel),
- permettre un redémarrage de la pipeline à la demande.

---

## 🧱 Architecture technique

### 🖥 Machine d'enregistrement (OBS)
- **OS** : Debian 12
- **Gestion audio** : PipeWire + PulseAudio
- **GStreamer** : utilisé pour recevoir et convertir le flux AES67
- **Dashboard** : Interface web Flask locale de supervision et contrôle

---

## 🔄 Chaîne de traitement du flux

1. **Émission** depuis la régie :
   - BUTT modifié → Stéréo Tool SDK (FM Pro) → AES67 multicast `239.69.145.58:5004`

2. **Réception sur la machine OBS** :
   - GStreamer écoute `239.69.145.58:5004` sur `eno1`
   - Convertit L24 → float32le
   - Envoie vers le sink PulseAudio nommé `aes67_sink`

3. **OBS** utilise une source "Monitor of aes67_sink" via PulseAudio pour intégrer l’audio dans la scène vidéo.

---

## ⚙️ GStreamer pipeline utilisée

```bash
gst-launch-1.0 udpsrc multicast-group=239.69.145.58     port=5004 caps="application/x-rtp,media=audio,clock-rate=48000,encoding-name=L24,channels=2"     ! rtpL24depay ! audioconvert ! audioresample     ! pulsesink client-name="aes67" stream-properties="props,media.role=music" device=aes67_sink
```

> 💡 La pipeline est encapsulée dans un **service systemd utilisateur** nommé `aes67.service`.

---

## 🧪 Supervision intégrée

Dashboard local Flask : `http://localhost:5000`

### Fonctions disponibles :
- ✅ État du service GStreamer (via `systemctl --user status aes67`)
- 📡 Écoute du port multicast via `ss` ou `tcpdump`
- 🎧 Vérification de la présence réelle d'audio via `sox` :
  ```bash
  sox -t pipewire aes67_sink.monitor -n stat
  ```
- 🔴 Détection de silence prolongé (RMS = 0.0 sur plusieurs tests)
- 🔁 Bouton de redémarrage du service `aes67.service`
- 📊 Visualisation des échantillons, RMS, max en temps réel
- 📶 Vérification du sink PulseAudio, de l’interface réseau, etc.

---

## 🔐 Automatisation et sécurité

- **Service systemd utilisateur** activé à l’ouverture de session
- **Dashboard local uniquement** (pas exposé publiquement)
- **Possibilité future** : intégration de login ou protection par VPN

---

## 📁 Fichiers clés

- `~/.config/systemd/user/aes67.service` → Service de réception GStreamer
- `start-aes67-l24.sh` → Script de lancement du pipeline
- `dashboard.py` → Application Flask
- `templates/` → HTML (Jinja2)
- `static/` → CSS et icônes

---

## ✅ Statut actuel

Le système est **opérationnel**, supervisé, utilisable par des non-techniciens via une interface web, et tolérant aux redémarrages ou aux interruptions de flux temporaires.

---

## 📌 Prochaines améliorations possibles

- Envoi de notifications (mail, Slack, Matrix) en cas de silence prolongé
- Historique des coupures et redémarrages (SQLite ou CSV)
- Interface responsive mobile
- Gestion des caméras NDI via OBS (en cours)

---

## ✊ Projet Cause Commune

Ce projet a été développé dans le cadre de la supervision technique des flux audio/vidéo de la radio **Cause Commune (93.1 FM à Paris)**, avec l’objectif de faciliter la production de contenus multimédias en direct tout en restant fidèle aux principes d'autonomie et de simplicité.

---
