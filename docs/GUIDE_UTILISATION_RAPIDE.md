# 🚀 Guide d'Utilisation Rapide - AES67 et Core Audio

## 🎯 **DÉMARRAGE RAPIDE**

### **Accès aux Nouvelles Fonctionnalités**
1. **Ouvrir BUTT**
2. **Settings** → **Onglet Audio**
3. **Faire défiler** → **Section "Advanced Audio Outputs"**

---

## 🎛️ **AES67 - Diffusion Réseau**

### **Configuration Standard**
```
✅ Enable AES67
IP Address: 239.69.145.58
Port: 5004
✅ Enable PTP
✅ Enable SAP
```

### **Utilisation**
- **Diffusion multicast** : Audio transmis sur le réseau
- **PTP** : Synchronisation temporelle précise
- **SAP** : Découverte automatique par les récepteurs
- **Status** : "Connected" quand actif

### **Cas d'Usage**
- **Studio de diffusion** : Envoi vers équipements AES67
- **Monitoring distant** : Écoute sur réseau local
- **Intégration système** : Compatible avec équipements professionnels

---

## 🎧 **Core Audio - Sortie macOS**

### **Configuration Standard**
```
✅ Enable Core Audio
Device: [Sélectionner votre périphérique]
Buffer: 20ms
✅ Exclusive Mode (optionnel)
```

### **Périphériques Détectés**
- **Bose S1 Pro** : Enceinte portable professionnelle
- **Haut-parleurs MacBook Pro** : Sortie intégrée
- **Microphone MacBook Pro** : Entrée intégrée
- **Loopback Audio** : Capture audio système

### **Utilisation**
- **Monitoring local** : Écoute directe sur macOS
- **Latence minimale** : Buffer 10-20ms recommandé
- **Mode exclusif** : Accès direct au périphérique
- **Status** : "Active" quand en cours

---

## 🔧 **Configuration Avancée**

### **AES67 - Paramètres Réseau**
```bash
# Réseau local standard
IP: 239.69.145.58
Port: 5004

# Réseau personnalisé
IP: 239.69.145.100
Port: 5004

# Configuration PTP/SAP
PTP: Activé (synchronisation)
SAP: Activé (découverte)
```

### **Core Audio - Optimisation Latence**
```bash
# Latence minimale
Buffer: 10ms
Exclusive Mode: Activé

# Latence équilibrée
Buffer: 20ms
Exclusive Mode: Désactivé

# Stabilité maximale
Buffer: 50ms
Exclusive Mode: Désactivé
```

---

## 🚨 **Dépannage Rapide**

### **Problème : AES67 ne se connecte pas**
```bash
# Vérifications
1. Réseau multicast activé
2. Firewall autorise port 5004
3. Test: ping 239.69.145.58
4. Vérifier switch/réseau
```

### **Problème : Core Audio pas de périphériques**
```bash
# Solutions
1. Redémarrer Core Audio:
   sudo pkill -HUP coreaudiod

2. Vérifier permissions:
   System Preferences → Security → Microphone

3. Lister périphériques:
   system_profiler SPAudioDataType
```

### **Problème : Segmentation fault à la fermeture**
```bash
# Solution
- Redémarrer BUTT
- Vérifier qu'aucun autre processus audio n'est actif
- Fermer proprement depuis l'interface
```

---

## 📊 **Scénarios d'Usage**

### **1. Diffusion Professionnelle**
```
AES67: Activé
- IP: 239.69.145.58
- Port: 5004
- PTP: Activé
- SAP: Activé

Core Audio: Activé
- Device: Bose S1 Pro
- Buffer: 20ms
- Exclusive: Activé
```

### **2. Monitoring Local**
```
AES67: Désactivé

Core Audio: Activé
- Device: Haut-parleurs MacBook Pro
- Buffer: 10ms
- Exclusive: Activé
```

### **3. Test et Développement**
```
AES67: Activé
- IP: 239.69.145.58
- Port: 5004
- PTP: Désactivé
- SAP: Désactivé

Core Audio: Activé
- Device: Loopback Audio
- Buffer: 50ms
- Exclusive: Désactivé
```

---

## ⚡ **Conseils d'Optimisation**

### **Performance AES67**
- **Réseau dédié** : Éviter le trafic concurrent
- **Switch multicast** : Équipement compatible
- **Latence réseau** : < 1ms recommandé
- **Bande passante** : ~2.3 Mbps par flux

### **Performance Core Audio**
- **Buffer minimal** : 10ms pour latence minimale
- **Mode exclusif** : Réduit la latence
- **Périphérique dédié** : Éviter les conflits
- **CPU disponible** : Éviter la surcharge

### **Configuration Hybride**
- **AES67 + Core Audio** : Compatible
- **Monitoring local** : Core Audio
- **Diffusion réseau** : AES67
- **Synchronisation** : PTP pour AES67

---

## 🔍 **Monitoring et Debug**

### **Logs AES67**
```bash
# Dans la console BUTT
AES67: Output initialized successfully
AES67: Audio format synchronized
AES67: Available devices: [liste]
AES67: Destination updated
AES67: PTP enabled
AES67: SAP announcements started
```

### **Logs Core Audio**
```bash
# Dans la console BUTT
Core Audio: Output initialized successfully
Core Audio: Audio format synchronized
Core Audio: Available devices: [liste]
Core Audio: Device updated
Core Audio: Buffer size updated
```

### **Statuts Interface**
```
AES67 Status: Connected/Disconnected
Core Audio Status: Active/Inactive
Core Audio Latency: 0ms (en temps réel)
```

---

## 📋 **Checklist de Configuration**

### **Avant Première Utilisation**
- [ ] **Vérifier réseau** : Multicast activé
- [ ] **Tester périphériques** : Core Audio fonctionnel
- [ ] **Configurer firewall** : Port 5004 ouvert
- [ ] **Vérifier permissions** : Audio macOS

### **Configuration AES67**
- [ ] **IP Address** : 239.69.145.58
- [ ] **Port** : 5004
- [ ] **Enable PTP** : ✓
- [ ] **Enable SAP** : ✓
- [ ] **Status** : Connected

### **Configuration Core Audio**
- [ ] **Device** : Sélectionné
- [ ] **Buffer** : 20ms
- [ ] **Exclusive Mode** : Optionnel
- [ ] **Status** : Active

### **Test Final**
- [ ] **Audio sort** : Vérifier l'audio
- [ ] **Latence** : Mesurer la latence
- [ ] **Stabilité** : Test longue durée
- [ ] **Fermeture** : Pas de crash

---

## 🆘 **Support et Aide**

### **Ressources**
- **Documentation complète** : `DOCUMENTATION_PHASE_1_AES67_CORE_AUDIO.md`
- **Logs détaillés** : Console BUTT
- **Tests réseau** : Scripts de diagnostic inclus

### **Problèmes Connus**
- **Segmentation fault** : Corrigé dans cette version
- **Sélecteur vide** : Détection automatique implémentée
- **Interface serrée** : Espacement amélioré

### **Contact**
- **Issues** : GitHub repository
- **Documentation** : Fichiers markdown inclus
- **Tests** : Scripts de validation fournis

---

*Guide créé le 26 juillet 2024 - BUTT Enhanced Phase 1* 