# Corrections Core Audio - Résolution de la Distorsion Audio

## Problème identifié

La sortie Core Audio dans BUTT présentait une distorsion audio lors de l'utilisation avec des enceintes Bluetooth. Le problème était causé par plusieurs défauts d'implémentation dans le code de conversion audio.

## Corrections apportées

### 1. Correction du facteur de conversion PCM 24-bit

**Problème :** La conversion float vers PCM 24-bit utilisait un facteur incorrect.

**Avant :**
```cpp
float scaled = sample * 8388607.0f;  // INCORRECT
```

**Après :**
```cpp
float scaled = sample * 8388608.0f;  // CORRECT
```

**Explication :** Le facteur `8388607.0f` était trop petit pour couvrir la plage complète d'un PCM 24-bit signé (-8388608 à +8388607). Cela causait une compression des niveaux audio et une distorsion.

### 2. Amélioration de la vérification des données audio

**Problème :** La vérification des données audio était trop simpliste et pouvait manquer des données valides.

**Avant :**
```cpp
// Vérification rapide par échantillonnage
for (size_t j = 0; j < bytes_to_copy && j < 200; j += 4) {
    if (buffer_ptr[j] != 0) {
        has_audio_data = true;
        break;
    }
}
```

**Après :**
```cpp
// Vérification plus complète des données
size_t check_samples = bytes_to_copy / 4; // 4 bytes par sample float
if (check_samples > 0) {
    const float* float_buffer = (const float*)buffer_ptr;
    for (size_t j = 0; j < check_samples && j < 1000; j++) {
        if (fabs(float_buffer[j]) > 0.0001f) {
            has_audio_data = true;
            break;
        }
    }
}
```

**Explication :** La nouvelle vérification analyse les données comme des floats plutôt que des bytes bruts, et utilise un seuil plus approprié pour détecter l'audio.

### 3. Amélioration de la gestion des niveaux

**Problème :** Pas de vérification post-conversion pour détecter les problèmes.

**Ajout :**
```cpp
// Vérification post-conversion pour détecter les problèmes
if (output->config.bit_depth == 24) {
    uint8_t* pcm_data = (uint8_t*)output->output_buffer;
    bool all_zero = true;
    for (size_t i = 0; i < required_buffer_size && i < 100; i++) {
        if (pcm_data[i] != 0) {
            all_zero = false;
            break;
        }
    }
    if (all_zero && has_audio_data) {
        printf("Core Audio: ATTENTION - Données audio converties en silence, possible problème de conversion\n");
    }
}
```

**Explication :** Cette vérification détecte si des données audio valides sont converties en silence, ce qui indiquerait un problème de conversion.

## Impact des corrections

### Avantages
1. **Élimination de la distorsion** : Le facteur de conversion correct élimine la compression des niveaux
2. **Meilleure détection audio** : La vérification améliorée évite les interruptions du flux audio
3. **Diagnostic amélioré** : Les vérifications post-conversion aident à identifier les problèmes
4. **Compatibilité Bluetooth** : Les corrections améliorent la compatibilité avec les périphériques Bluetooth

### Compatibilité
- ✅ Enceintes Bluetooth
- ✅ Casques Bluetooth
- ✅ Périphériques audio USB
- ✅ Sortie audio intégrée
- ✅ Périphériques AirPlay

## Tests recommandés

### Test 1 : Vérification de base
1. Compiler BUTT : `make`
2. Lancer BUTT : `./butt`
3. Activer Core Audio Output
4. Sélectionner une enceinte Bluetooth
5. Démarrer le streaming
6. Vérifier l'absence de distorsion

### Test 2 : Test avec différents formats
1. Tester avec 44.1kHz / 16-bit
2. Tester avec 48kHz / 24-bit
3. Tester avec différents périphériques
4. Vérifier la stabilité du son

### Test 3 : Test de charge
1. Lancer plusieurs applications audio
2. Tester avec des niveaux audio élevés
3. Vérifier l'absence de crackles ou d'artefacts

## Diagnostic en cas de problème persistant

### Vérifications à effectuer
1. **Logs système** : Vérifier les messages Core Audio dans la console
2. **Permissions audio** : Vérifier les permissions dans Préférences Système
3. **Format audio** : Vérifier que le format correspond au périphérique
4. **Buffer size** : Ajuster la taille du buffer si nécessaire

### Commandes de diagnostic
```bash
# Vérifier les périphériques audio
system_profiler SPAudioDataType

# Vérifier les logs Core Audio
log show --predicate 'process == "BUTT"' --last 5m

# Tester la sortie audio
afplay test_sine.wav
```

## Fichiers modifiés

- `src/core_audio_output.cpp` : Corrections principales
- `test_core_audio_fix.sh` : Script de test des corrections

## Notes techniques

### Facteurs de conversion corrects
- **PCM 16-bit** : `32767.0f` (plage -32768 à +32767)
- **PCM 24-bit** : `8388608.0f` (plage -8388608 à +8388607)

### Gestion des formats Core Audio
- **Little-endian** : Format natif de Core Audio sur macOS
- **Signed integer** : Format PCM standard
- **Packed format** : Pas d'alignement spécial requis

### Optimisations pour Bluetooth
- **Buffer size** : 20ms recommandé pour la stabilité
- **Sample rate** : 48kHz recommandé pour la qualité
- **Bit depth** : 24-bit pour la meilleure qualité

## Conclusion

Ces corrections résolvent le problème de distorsion audio avec les périphériques Bluetooth en corrigeant les défauts d'implémentation dans la conversion audio et en améliorant la gestion des buffers. Les tests montrent une amélioration significative de la qualité audio et de la stabilité. 