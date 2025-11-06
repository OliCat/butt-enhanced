# 🔧 Guide de Dépannage AES67 - BUTT Enhanced v0.3

Ce guide vous aide à diagnostiquer et résoudre les problèmes courants avec la sortie AES67 de BUTT Enhanced.

---

## 🎯 Problèmes Courants et Solutions

### 1. 🔌 Aucun Son / Pas de Réception

#### Symptômes
- BUTT indique "Connecté" mais pas de son côté récepteur
- Métriques montrent 0 pps/kbps
- Récepteur ne détecte aucun flux

#### Solutions

**Vérifier la configuration de base :**
```
1. IP de destination : Doit être multicast (239.x.x.x) ou unicast valide
2. Port : Généralement 5004 (standard) ou spécifique au récepteur
3. Interface réseau : Sélectionner la bonne carte réseau
4. Audio source : Vérifier que l'audio entre bien dans BUTT
```

**Interface AES67 dans BUTT :**
- ✅ Checkbox "Enable AES67" cochée
- ✅ IP de destination valide (ex: `239.69.145.58`)
- ✅ Port correct (ex: `5004`)
- ✅ Statut affiche "Connecté" avec métriques > 0

### 2. 🌐 Problèmes Réseau

#### TTL (Time To Live) Multicast

**Symptôme :** Pas de réception sur d'autres subnets
```
Solution : Augmenter le TTL
- Valeur par défaut : 32
- LAN local : TTL = 1
- Plusieurs subnets : TTL = 64-128
- WAN : TTL = 255
```

**Configuration TTL dans BUTT :**
```cpp
// Via code (aes67_output.cpp)
aes67_output_set_ttl(aes67_output, 64);

// Via config (cfg.cpp)
cfg.aes67.ttl = 64;
```

#### Interface Réseau

**Symptôme :** Multicast ne sort pas par la bonne interface
```
Solution : Spécifier l'interface
- Obtenir l'IP de l'interface : ifconfig (macOS/Linux) ou ipconfig (Windows)
- Configurer dans BUTT : Interface = "192.168.1.100" (IP de votre carte)
```

**Code de configuration :**
```cpp
aes67_output_set_interface(aes67_output, "192.168.1.100");
```

#### DSCP / QoS

**Symptôme :** Paquets perdus en réseau chargé
```
Solution : Configurer DSCP pour priorisation
- Valeur recommandée : 46 (EF - Expedited Forwarding)
- Autres valeurs : 34 (AF41), 26 (AF31)
```

### 3. ⏱️ Problèmes de Timing / Jitter

#### PTP (Precision Time Protocol)

**Symptôme :** Jitter élevé, synchronisation imprécise

**Sans PTP (par défaut) :**
- ✅ Mini-PLL activé automatiquement
- ✅ Correction progressive des dérives
- ✅ Pas de configuration supplémentaire

**Avec PTP (réseaux professionnels) :**
```
Configuration requise :
1. Master PTP sur le réseau
2. Domaine PTP configuré (généralement 0-127)
3. Interface compatible PTP
```

**Activation PTP dans BUTT :**
- ☑️ Checkbox "Enable PTP"
- Configuration domaine : via config avancée

#### Mesure de Performance

**Script de diagnostic :**
```bash
# Mesurer les intervalles inter-paquets
cd butt-enhanced
python3 tests/measure_packet_intervals.py 239.69.145.58 5004 60

# Résultats attendus :
# - Moyenne : ~1000 µs
# - Écart-type : < 100 µs
# - Pertes : < 0.01%
```

### 4. 🎵 Problèmes Audio

#### Format L24 vs PCM16

**Configuration dans BUTT :**
- Par défaut : L24 (24-bit) - Recommandé pour AES67
- Alternative : PCM16 (16-bit) - Compatibilité élargie

**Vérification format :**
```bash
# Capturer et analyser avec Wireshark
# Filtrer : rtp and ip.dst == 239.69.145.58
# Vérifier : Payload Type = 96 (L24) ou 10 (PCM16)
```

#### Distorsion / Écrêtage

**Symptômes :** Son saturé, distordu
```
Solutions :
1. Vérifier gain d'entrée BUTT
2. Contrôler niveaux VU-mètres
3. Ajuster processing StereoTool si activé
4. Vérifier clip_protection activé (par défaut : ON)
```

#### Latence

**Diagnostic latence :**
- Interface BUTT : Affichage "Latency: XXms" en temps réel
- StereoTool : Latence interne exposée automatiquement
- Buffers : Ajustement automatique selon latence détectée

### 5. 🔧 SDP et SAP

#### Description SDP

**Problème :** Récepteur ne reconnaît pas le flux

**Solution - Vérifier SDP :**
```
1. BUTT → AES67 → Bouton "Copier SDP"
2. Coller dans éditeur de texte
3. Vérifier format :
   - v=0 (version)
   - o= (origine)
   - c=IN IP4 239.69.145.58 (connexion)
   - m=audio 5004 RTP/AVP 96 (media)
   - a=rtpmap:96 L24/48000/2 (format)
```

**SDP Type :**
```sdp
v=0
o=BUTT 123456 1 IN IP4 192.168.1.100
s=BUTT AES67 Stream
c=IN IP4 239.69.145.58/32
t=0 0
m=audio 5004 RTP/AVP 96
a=rtpmap:96 L24/48000/2
a=ptime:1
a=mediaclk:direct=0
```

#### SAP (Session Announcement Protocol)

**Fonction :** Annonce automatique du flux sur le réseau
- Port SAP : 9875 (multicast 224.2.127.254)
- ☑️ Checkbox "Enable SAP" pour activation
- Détection automatique par récepteurs compatibles

### 6. 🖥️ Interface et Configuration

#### Validation des Champs

**Messages d'erreur BUTT v0.3 :**
- ❌ "Adresse IP invalide" → Vérifier format IPv4
- ❌ "Port invalide" → Utiliser 1-65535
- ❌ "TTL invalide" → Utiliser 1-255
- ❌ "DSCP invalide" → Utiliser 0-63

#### Statut Temps Réel

**Indicateurs :**
- 🟢 "Statut: ● Connecté" → Envoi actif
- 🔴 "Statut: ○ Déconnecté" → Problème config/réseau
- 📊 "X pps, Y kbps" → Métriques trafic temps réel

---

## 🔍 Outils de Diagnostic

### 1. Scripts BUTT Enhanced

**Tests intégrés :**
```bash
# Test réseau complet
make -f Makefile.v03 test

# Test spécifique AES67
python3 tests/measure_packet_intervals.py [IP] [PORT] [DURÉE]

# Test d'endurance
./tests/soak_test.sh 3600  # 1 heure
```

### 2. Outils Système

**macOS :**
```bash
# Vérifier interface multicast
netstat -rn | grep 224
netstat -g  # Groupes multicast

# Capturer trafic
sudo tcpdump -i en0 host 239.69.145.58

# Monitoring réseau
nettop -p -d  # Trafic par processus
```

**Linux :**
```bash
# Routes multicast
ip route show table all | grep 224

# Interfaces multicast
ip maddr show

# Capture Wireshark en ligne de commande
tshark -i eth0 -f "host 239.69.145.58"
```

### 3. Wireshark

**Filtres utiles :**
```
# Tout le trafic AES67
rtp and ip.dst == 239.69.145.58

# Analyse timing
rtp.timestamp and ip.dst == 239.69.145.58

# SAP announcements
sap
```

**Analyse RTP :**
1. Statistics → RTP → RTP Streams
2. Sélectionner le flux AES67
3. Analyze → Statistiques de jitter, pertes, etc.

---

## 🚨 Résolution d'Urgence

### Pas de Son - Checklist 30 Secondes

1. ✅ BUTT : Audio entre ? (VU-mètres bougent)
2. ✅ AES67 : Enable AES67 coché ?
3. ✅ IP : Format correct ? (ex: 239.69.145.58)
4. ✅ Port : Correct ? (ex: 5004)
5. ✅ Statut : "Connecté" avec pps > 0 ?
6. ✅ Réseau : Ping vers destination OK ?

### Dépannage Express

**Étape 1 - Vérification basique :**
```bash
ping 239.69.145.58  # Doit répondre si multicast routé
```

**Étape 2 - Test local :**
```bash
# Changer temporairement en unicast local
IP: 127.0.0.1  # Loopback
# Si ça marche → problème réseau
# Si ça marche pas → problème BUTT
```

**Étape 3 - Redémarrage :**
```
1. Désactiver AES67
2. Attendre 5 secondes  
3. Réactiver AES67
4. Vérifier statut
```

---

## 📞 Support Avancé

### Logs de Debug

**Activation :**
- Compiler avec `DEBUG=1 make`
- Ou consulter logs existants dans interface BUTT

**Éléments à chercher :**
```
AES67: Output initialized successfully
AES67: Socket configuré
StereoTool: Latence mise à jour: X ms
Audio Buffers: Taille ajustée
```

### Configuration IPv6

**Support :** Actuellement IPv4 uniquement
**Alternative :** Utiliser tunneling IPv6→IPv4 si nécessaire

### Firewall / Sécurité

**Ports à ouvrir :**
- UDP 5004 (flux AES67)
- UDP 9875 (SAP announcements)
- UDP 319-320 (PTP si activé)

---

## 📚 Références Techniques

- **RFC 3190** : RTP Payload Format for 12-bit DAT Audio and 20- and 24-bit Linear Sampled Audio
- **AES67-2018** : AES standard for audio applications of networks - High-performance streaming audio-over-IP interoperability
- **RFC 3550** : RTP: A Transport Protocol for Real-Time Applications
- **IEEE 1588** : Precision Time Protocol (PTP)

---

*Guide mis à jour pour BUTT Enhanced v0.3 - Novembre 2024* 🎵
