# 🎵 Guide Core Audio - BUTT Enhanced

## 📋 Vue d'Ensemble

**Core Audio** est l'API audio native de macOS qui offre une latence ultra-faible et une qualité audio optimale. Cette implémentation s'intègre parfaitement avec votre pipeline audio BUTT existant.

### ✅ Avantages Core Audio
- **Latence ultra-faible** : ~5-10ms de latence hardware
- **Qualité audio native** : Pas de conversion intermédiaire
- **Compatibilité parfaite** : Fonctionne avec tous les périphériques macOS
- **Performance optimale** : Utilise les APIs natives Apple
- **Intégration transparente** : S'intègre avec StereoTool et AES67

## 🏗️ Architecture Technique

### Composants Ajoutés

#### 1. `src/core_audio_output.h`
- **Structure de configuration** : `core_audio_config_t` avec paramètres audio
- **Instance de sortie** : `core_audio_output_t` avec buffer et état
- **API complète** : 12 fonctions principales pour gestion Core Audio
- **Interface C** : Compatible avec le code C++ existant de BUTT

#### 2. `src/core_audio_output.cpp`
- **Audio Unit** : Utilise `kAudioUnitSubType_DefaultOutput`
- **Callback natif** : `core_audio_callback()` pour la sortie audio
- **Conversion PCM** : Float vers PCM 16/24-bit optimisée
- **Gestion d'erreurs** : Validation complète des paramètres

#### 3. Intégration dans `src/port_audio.cpp`
- **Initialisation sécurisée** : `snd_init_core_audio()` après initialisation audio
- **Pipeline audio** : Envoi Core Audio dans le thread de mixage
- **Nettoyage** : Libération des ressources dans `snd_close_streams()`

## 🚀 Utilisation

### 1. Compilation
```bash
cd butt-enhanced
make clean
make
```

### 2. Test de Compilation
```bash
# Vérifier les symboles Core Audio
nm src/butt | grep core_audio

# Test de lancement
./src/butt --help
```

### 3. Lancement et Vérification
```bash
# Lancer BUTT
./src/butt

# Vérifier les logs Core Audio
# Chercher : "Core Audio: Output initialized successfully"
```

## ⚙️ Configuration

### Paramètres par Défaut
- **Sample Rate** : 48kHz (synchronisé avec le système)
- **Channels** : 2 (stéréo)
- **Bit Depth** : 24-bit
- **Buffer Size** : 10ms
- **Device** : Default (Built-in Output)
- **Mode** : Non-exclusif (partage avec autres apps)

### Configuration Avancée
```c
// Dans le code, vous pouvez modifier :
core_audio_output_set_audio_format(output, 48000, 2, 24);
core_audio_output_set_buffer_size(output, 5); // 5ms pour latence ultra-faible
core_audio_output_set_device(output, "Nom du périphérique");
core_audio_output_set_exclusive_mode(output, true); // Mode exclusif
```

## 🎯 Fonctionnalités

### 1. Sortie Audio Locale
- **Audio traité** : Sortie directe du son traité par StereoTool
- **Latence minimale** : ~5-10ms de latence totale
- **Qualité native** : Pas de dégradation audio

### 2. Gestion des Périphériques
- **Détection automatique** : Liste des périphériques disponibles
- **Configuration flexible** : Changement de périphérique à la volée
- **Mode exclusif** : Accès exclusif au périphérique (optionnel)

### 3. Synchronisation Audio
- **Format synchronisé** : Même format que le système audio
- **Buffer optimisé** : Taille de buffer adaptative
- **Timing précis** : Synchronisation avec le pipeline audio

## 🔧 Dépannage

### Problèmes Courants

#### 1. Erreur d'Initialisation
```
Core Audio: Erreur lors de la création de l'Audio Unit
```
**Solution** : Vérifier les permissions audio dans Préférences Système

#### 2. Pas de Son
```
Core Audio: Sortie initialisée mais pas de son
```
**Solution** : 
- Vérifier le volume système
- Vérifier le périphérique de sortie
- Tester avec un autre périphérique

#### 3. Latence Élevée
```
Core Audio: Latence > 20ms
```
**Solution** :
- Réduire la taille du buffer (5ms au lieu de 10ms)
- Vérifier les autres applications audio
- Mode exclusif si nécessaire

### Tests de Diagnostic

#### 1. Test de Base
```bash
./test_core_audio.sh
```

#### 2. Test de Latence
```bash
# Mesurer la latence avec un oscillateur
# Générer un signal de test et mesurer le délai
```

#### 3. Test de Qualité
```bash
# Comparer avec la sortie AES67
# Vérifier la fidélité audio
```

## 📊 Comparaison avec AES67

| Aspect | Core Audio | AES67 |
|--------|------------|-------|
| **Latence** | ~5-10ms | ~20-50ms |
| **Qualité** | Native | Excellente |
| **Portée** | Locale | Réseau |
| **Complexité** | Simple | Complexe |
| **Usage** | Monitoring | Diffusion |

## 🎵 Cas d'Usage

### 1. Monitoring Local
- **Usage** : Écouter le son traité localement
- **Avantage** : Latence ultra-faible pour monitoring en temps réel
- **Configuration** : Buffer 5ms, mode non-exclusif

### 2. Test de Qualité
- **Usage** : Vérifier la qualité du traitement StereoTool
- **Avantage** : Qualité native sans dégradation réseau
- **Configuration** : Buffer 10ms, format 24-bit

### 3. Backup Audio
- **Usage** : Sortie de secours si AES67 échoue
- **Avantage** : Fonctionne même sans réseau
- **Configuration** : Même format que AES67

## 🔮 Évolutions Futures

### 1. Interface Utilisateur
- **Sélection de périphérique** : Menu déroulant dans l'interface
- **Configuration buffer** : Slider pour ajuster la latence
- **Mode exclusif** : Checkbox pour l'accès exclusif

### 2. Fonctionnalités Avancées
- **Multi-périphérique** : Sortie sur plusieurs périphériques
- **Format adaptatif** : Changement automatique de format
- **Monitoring avancé** : VU-mètres dédiés Core Audio

### 3. Intégration Réseau
- **Core Audio + AES67** : Sortie simultanée locale et réseau
- **Synchronisation** : Timing précis entre les sorties
- **Fallback automatique** : Basculement automatique

## ✅ Validation

### Checklist de Test
- [ ] Compilation réussie
- [ ] Lancement sans erreur
- [ ] Initialisation Core Audio
- [ ] Sortie audio fonctionnelle
- [ ] Latence acceptable (< 20ms)
- [ ] Qualité audio correcte
- [ ] Nettoyage des ressources

### Logs de Succès
```
Core Audio: Sortie initialisée - 48000Hz, 2 canaux, 24 bits, buffer 10ms
Core Audio: Sortie démarrée
Core Audio: Output initialized successfully
Core Audio: Audio format synchronized with system settings
```

## 🎉 Conclusion

L'implémentation Core Audio offre une **sortie audio locale de qualité professionnelle** avec une latence ultra-faible. Elle complète parfaitement votre système AES67 en offrant une solution de monitoring local fiable et performante.

**Prochaine étape** : Testez la compilation et le lancement de BUTT avec Core Audio ! 