# 🚨 Résolution Processus Zombie BUTT AES67

## 📋 **RÉSUMÉ DE LA SITUATION**

### **Problème Identifié**
- **Processus zombie BUTT** (PID 82519) en état `UE+` (Uninterruptible sleep)
- **Socket UDP bloqué** sur le port par défaut
- **Résistant aux signaux** système (TERM, INT, QUIT, KILL)
- **Cleanup AES67 incomplet** lors de la fermeture

### **État Actuel**
- ✅ **Nouveau BUTT fonctionnel** (PID 55270) avec 43,2% CPU
- ⚠️ **Zombie persistant** (PID 82519) avec 66 fichiers ouverts
- ⚠️ **2 connexions AES67** actives
- ⚠️ **2 connexions SAP** actives

---

## 🔍 **ANALYSE TECHNIQUE**

### **Cause Racine**
Le problème vient de l'implémentation AES67 dans BUTT :

1. **Threads non-terminés** : Les threads PTP/SAP ne reçoivent pas le signal d'arrêt
2. **Socket bloqué** : Le socket UDP reste ouvert et bloque le processus
3. **Race condition** : `exit(0)` brutal interrompt le cleanup
4. **Cleanup incomplet** : Les ressources réseau ne sont pas libérées

### **Code Problématique**
```cpp
// Dans window_main_close_cb()
snd_close_streams();     // ← Cleanup AES67 ici
snd_close_portaudio();
exit(0);                 // ← Exit brutal pendant cleanup
```

### **Cleanup AES67 Actuel**
```cpp
void aes67_output_cleanup(aes67_output_t* output) {
    if (aes67_socket >= 0) {
        close(aes67_socket);  // ← Peut bloquer
    }
    // Pas de timeout sur les threads
    ptp_cleanup(&output->ptp_state);
    sap_cleanup(&output->sap_state);
}
```

---

## 🛠️ **SOLUTIONS IMMÉDIATES**

### **Solution 1: Workaround Opérationnel** ✅
Le nouveau BUTT (PID 55270) fonctionne correctement. Le zombie n'empêche pas l'usage.

**Actions recommandées :**
```bash
# Monitorer le nouveau BUTT
watch 'ps aux | grep butt'

# Vérifier les logs
tail -f /tmp/butt_final_*.log

# Utiliser BUTT normalement
# Le zombie sera libéré au redémarrage système
```

### **Solution 2: Scripts de Gestion** ✅
Scripts créés pour la gestion quotidienne :

- `diagnostic_cleanup_avance.sh` : Diagnostic complet
- `solution_immediate_zombie.sh` : Solution immédiate
- `solution_finale_zombie.sh` : Solution radicale

### **Solution 3: Fix Code Source** 🔄
Patch créé pour corriger le problème à la source :

- **Arrêt propre AES67** avant autres ressources
- **Timeout sur les threads** PTP/SAP
- **Logs détaillés** du processus de fermeture
- **Vérification des états** avant exit()

---

## 🔧 **SOLUTIONS À LONG TERME**

### **Fix 1: Améliorer Séquence Fermeture**
```cpp
void window_main_close_cb(bool ask) {
    // 1. Arrêter AES67 en premier
    aes67_output_t* aes67_output = aes67_output_get_global_instance();
    if (aes67_output && aes67_output->initialized) {
        aes67_output->config.active = false;
        aes67_output_stop_sap_announcements(aes67_output);
        ptp_stop_sync(&aes67_output->ptp_state);
        
        // Attendre threads avec timeout
        int timeout = 0;
        while (timeout < 50) {  // 5 secondes max
            if (!aes67_output->ptp_state.config.enabled) break;
            usleep(100000);  // 100ms
            timeout++;
        }
    }
    
    // 2. Cleanup normal
    stop_recording(false);
    button_disconnect_cb(false);
    snd_close_streams();
    snd_close_portaudio();
    
    // 3. Exit propre
    exit(0);
}
```

### **Fix 2: Thread Management Robuste**
```cpp
// Dans aes67_ptp.cpp et aes67_sap.cpp
static void* ptp_sync_thread(void* arg) {
    while (ptp_thread_running && ptp_state->config.enabled) {
        // Vérifier si arrêt demandé
        if (!ptp_thread_running) break;
        
        // Traitement normal
        ptp_send_sync_message(ptp_state);
        usleep(ptp_state->config.sync_interval_ms * 1000);
    }
    return NULL;
}
```

### **Fix 3: Socket Management**
```cpp
void aes67_output_cleanup(aes67_output_t* output) {
    if (aes67_socket >= 0) {
        // Non-blocking close
        fcntl(aes67_socket, F_SETFL, O_NONBLOCK);
        close(aes67_socket);
        aes67_socket = -1;
    }
    
    // Timeout sur threads
    pthread_t threads[] = {ptp_thread, sap_thread};
    for (int i = 0; i < 2; i++) {
        struct timespec timeout = {.tv_sec = 2};
        pthread_timedjoin_np(threads[i], NULL, &timeout);
    }
}
```

---

## 📊 **PLAN D'ACTION**

### **Phase 1: Stabilisation (Cette Semaine)**
- [x] **Diagnostic complet** du problème
- [x] **Scripts de gestion** créés
- [x] **Workaround opérationnel** en place
- [ ] **Monitoring continu** du nouveau BUTT
- [ ] **Tests de stabilité** (24h+)

### **Phase 2: Fix Code (Semaine Prochaine)**
- [ ] **Application du patch** de correction
- [ ] **Tests de fermeture** répétés
- [ ] **Validation cleanup** complet
- [ ] **Tests de stress** (multiples start/stop)

### **Phase 3: Production (Semaine Suivante)**
- [ ] **Déploiement** du fix en production
- [ ] **Monitoring** long terme
- [ ] **Documentation** des procédures
- [ ] **Formation** équipe

---

## 🎯 **RECOMMANDATIONS IMMÉDIATES**

### **Pour Usage Production**
1. **Utiliser le nouveau BUTT** (PID 55270) normalement
2. **Ignorer le zombie** (PID 82519) - il sera libéré au redémarrage
3. **Monitorer** : `watch 'ps aux | grep butt'`
4. **Vérifier logs** : `tail -f /tmp/butt_final_*.log`

### **Pour Éviter Futurs Problèmes**
1. **Toujours fermer BUTT** via interface graphique
2. **Attendre 5 secondes** avant relancer
3. **Utiliser les scripts** en cas de problème
4. **Redémarrer système** si nécessaire

### **Pour Développement**
1. **Appliquer le patch** de correction
2. **Tester fermeture** proprement
3. **Implémenter timeout** sur threads
4. **Ajouter logs** détaillés

---

## 📞 **CONTACTS & SUIVI**

**Reporter** : Claude (Assistant technique)  
**Affecté** : @ogrieco (Développeur principal)  
**Priorité** : P1 (Important - workaround en place)  
**Status** : Workaround opérationnel, fix en développement  

**Prochaine Review** : 2 août 2024  
**Target Fix** : 15 août 2024

---

## 💡 **CONCLUSION**

Le problème du processus zombie BUTT est **identifié et maîtrisé** :

- ✅ **Workaround opérationnel** en place
- ✅ **Nouveau BUTT fonctionnel** 
- ✅ **Scripts de gestion** créés
- 🔄 **Fix code source** en développement

**BUTT peut être utilisé en production** avec le nouveau processus. Le zombie sera libéré au prochain redémarrage système.

**Dernière mise à jour** : 26 juillet 2024 