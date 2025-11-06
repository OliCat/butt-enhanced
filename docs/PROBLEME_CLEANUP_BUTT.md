# 🚨 Problème Cleanup BUTT Enhanced - Bug Report

## 📋 **RÉSUMÉ PROBLÈME**

BUTT Enhanced présente un **bug critique de cleanup** qui génère des processus **orphelins/zombies** résistants aux signaux système.

---

## 🔍 **SYMPTÔMES OBSERVÉS**

### **Comportement Normal Attendu**
- 1 seul processus BUTT actif
- Fermeture propre avec libération ressources
- Pas de conflit avec autres apps audio

### **Comportement Problématique Observé**
- ✅ **Qobuz interface figée** quand BUTT actif
- ✅ **Multiples processus BUTT** simultanés
- ✅ **Processus zombie unkillable** (résiste `kill -9`)
- ✅ **Consommation CPU excessive** (60-80%)
- ✅ **Ressources réseau non libérées** (sockets AES67/SAP)

---

## 📊 **EXEMPLES CONCRETS**

### **Processus Multiples Détectés**
```bash
# Status typique problématique:
PID    %CPU  %MEM  COMMAND
99344  62,9  1,1   ./src/butt  ← Processus principal actif
82519  0,0   0,1   ./src/butt  ← Zombie unkillable (depuis 10h+)
```

### **Connexions Réseau Persistantes**
```bash
# Connexions qui restent ouvertes:
butt  86014  UDP *:51345
butt  86014  UDP 172.20.10.8:64285->sap.mcast.net:sapv1  
butt  86014  TCP localhost:de-server (LISTEN)
```

---

## 🧬 **ANALYSE TECHNIQUE**

### **Code de Fermeture Actuel**
Le code dans `fl_callbacks.cpp::window_main_close_cb()` fait :
```cpp
stop_recording(false);
button_disconnect_cb(false);
command_stop_server();
snd_close_streams();     // ← Contient cleanup AES67
snd_close_portaudio();
cfg_write_file(NULL);
url_cleanup_curl();
exit(0);                 // ← exit() brutal
```

### **Cleanup AES67 Ajouté**
Dans `port_audio.cpp::snd_close_streams()` :
```cpp
// Cleanup StereoTool
stereo_tool_cleanup();

// Cleanup AES67 output  ← NOUVEAU CODE
aes67_output_t* aes67_output = aes67_output_get_global_instance();
if (aes67_output) {
    aes67_output_cleanup(aes67_output);  // ← Peut bloquer?
}
```

### **Hypothèses Causes**

#### **Cause A: Threads AES67 Non-Terminés**
- Threads RTP transmission en boucle
- Threads PTP/SAP qui ne reçoivent pas signal stop
- `pthread_join()` manquant ou bloqué

#### **Cause B: Sockets Réseau Bloquées**
- Socket multicast AES67 en état bloquant
- Appels `close()` qui ne retournent pas
- Deadlock sur `bind()/connect()`

#### **Cause C: Race Condition Exit**
- `exit(0)` brutal pendant cleanup
- Concurrent access aux structures globales
- FLTK/PortAudio cleanup incomplet

#### **Cause D: Core Audio Deadlock**
- PortAudio streams pas complètement fermés
- Core Audio HAL en deadlock
- Device audio locks non libérés

---

## 🛠️ **SOLUTIONS TESTÉES**

### **Solution 1: Scripts Emergency** ✅
```bash
# Scripts créés pour mitigation:
./restart_qobuz_clean.sh      # Fix conflit Qobuz
./fix_butt_cleanup.sh         # Cleanup processus
./emergency_audio_fix.sh      # Reset complet
```
**Résultat** : Résout temporairement mais ne corrige pas la cause

### **Solution 2: Kill Force** ❌
```bash
# Même sudo kill -9 échoue:
sudo kill -9 82519
# → Processus persiste
```
**Résultat** : Processus zombie kernel-level impossible à tuer

---

## 🔧 **SOLUTIONS PROPOSÉES**

### **Fix A: Améliorer Séquence Fermeture**
```cpp
// Dans window_main_close_cb():
void window_main_close_cb(bool ask) {
    // 1. Stop gracefully AES67 FIRST
    aes67_output_stop_graceful();
    
    // 2. Wait for threads completion
    aes67_wait_threads_completion(5000); // 5s timeout
    
    // 3. Then normal cleanup
    stop_recording(false);
    button_disconnect_cb(false);
    
    // 4. Explicit thread cleanup
    snd_stop_all_threads();
    
    // 5. Close audio last
    snd_close_streams();
    snd_close_portaudio();
    
    // 6. Clean exit (pas exit() brutal)
    _exit(0);
}
```

### **Fix B: AES67 Threads Cleanup**
```cpp
// Dans aes67_output_cleanup():
void aes67_output_cleanup(aes67_output_t* output) {
    if (!output) return;
    
    // 1. Signal stop à tous les threads
    output->stop_requested = true;
    
    // 2. Attendre threads avec timeout
    pthread_t threads[] = {output->rtp_thread, output->sap_thread, output->ptp_thread};
    for (int i = 0; i < 3; i++) {
        struct timespec timeout = {.tv_sec = 2};
        pthread_timedjoin_np(threads[i], NULL, &timeout);
    }
    
    // 3. Force kill threads si timeout
    // pthread_cancel() si nécessaire
    
    // 4. Close sockets avec timeout
    if (aes67_socket >= 0) {
        fcntl(aes67_socket, F_SETFL, O_NONBLOCK);
        close(aes67_socket);
        aes67_socket = -1;
    }
    
    // 5. Free resources
    free(output->output_buffer);
    output->output_buffer = NULL;
}
```

### **Fix C: Signal Handlers Propres**
```cpp
// Ajouter gestionnaire signaux:
void setup_signal_handlers() {
    signal(SIGTERM, graceful_shutdown);
    signal(SIGINT, graceful_shutdown);
    signal(SIGQUIT, graceful_shutdown);
}

void graceful_shutdown(int sig) {
    printf("Signal %d reçu, fermeture propre...\n", sig);
    window_main_close_cb(false);
}
```

---

## 📋 **PLAN D'ACTION**

### **Phase 1: Investigation (Cette Semaine)**
- [ ] **Strace processus zombie** : `sudo strace -p 82519`
- [ ] **Analyse threads** : `sudo gdb -p 82519`
- [ ] **Monitor système calls** : `sudo dtruss -p processus_butt`
- [ ] **Review code AES67** cleanup complet

### **Phase 2: Fix Code (Semaine Prochaine)**
- [ ] **Implémentation cleanup amélioré**
- [ ] **Thread management robuste**
- [ ] **Signal handlers propres**
- [ ] **Tests fermeture/ouverture répétées**

### **Phase 3: Tests Production**
- [ ] **Tests longue durée** (24h+)
- [ ] **Tests stress** (multiples start/stop)
- [ ] **Tests compatibility** avec autres apps audio
- [ ] **Validation équipement broadcast**

---

## 🎯 **PRIORITÉS**

### **P0 - URGENT** ✅
- [x] **Résoudre conflit Qobuz** (FAIT - scripts emergency)
- [x] **Usage studio immédiat** (FAIT - workaround opérationnel)

### **P1 - IMPORTANT**
- [ ] **Fix processus zombie** (investigation kernel)
- [ ] **Réduire CPU usage** BUTT (<10%)
- [ ] **Cleanup code robuste**

### **P2 - SOUHAITABLE**
- [ ] **Monitoring processus** intégré
- [ ] **Auto-restart** en cas problème
- [ ] **Metrics cleanup** (prometheus/grafana)

---

## 💡 **WORKAROUNDS IMMÉDIATS**

### **Pour Studio Production**
```bash
# 1. Monitoring continu:
watch 'ps aux | grep butt | grep -v grep'

# 2. Cleanup périodique:
# Tous les matins avant session:
./fix_butt_cleanup.sh

# 3. Restart Qobuz si figé:
./restart_qobuz_clean.sh

# 4. En cas urgence live:
./emergency_audio_fix.sh
```

### **Workflow Recommandé**
1. **Démarrer BUTT** en premier
2. **Attendre stabilisation** (30s)
3. **Lancer Qobuz** ensuite
4. **Monitoring CPU** pendant session
5. **Fermeture propre** via interface BUTT

---

## 📞 **CONTACTS & SUIVI**

**Reporter** : Claude (Assistant technique)  
**Affecté** : @ogrieco (Développeur principal)  
**Priorité** : P1 (Important - pas bloquant immédiat)  
**Status** : Investigation en cours  

**Prochaine Review** : 2 août 2024  
**Target Fix** : 15 août 2024

---

> **Note** : Ce bug n'empêche PAS l'usage en production grâce aux scripts de workaround, mais doit être corrigé pour la stabilité long terme.

**Dernière mise à jour** : 26 juillet 2024 