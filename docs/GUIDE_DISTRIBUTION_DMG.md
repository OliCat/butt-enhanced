# 🚀 Guide de Distribution DMG - BUTT Enhanced

## Vue d'ensemble

Ce guide explique comment construire et distribuer un DMG macOS pour BUTT Enhanced avec StereoTool SDK intégré. Le processus est optimisé pour la distribution privée sans passer par l'App Store.

## 📋 Prérequis

### Système
- macOS 10.12+ (Sierra ou plus récent)
- Xcode Command Line Tools installés
- Architecture ARM64 (Apple Silicon) ou x86_64 (Intel)

### Outils requis
```bash
# Vérifier la présence des outils
which otool install_name_tool lipo hdiutil codesign
```

### Dépendances
- StereoTool SDK (licence Pro)
- Toutes les dépendances système (FLTK, PortAudio, etc.)

## 🛠️ Construction du DMG

### Méthode 1: Script automatisé (Recommandé)

```bash
# Construction ARM64 (par défaut)
./scripts/build_universal_dmg.sh

# Construction x86_64
./scripts/build_universal_dmg.sh --arch x86_64

# Construction avec options
./scripts/build_universal_dmg.sh --arch arm64 --no-clean --sign
```

### Méthode 2: Construction manuelle

```bash
# 1. Compilation
./configure --host=arm64-apple-darwin \
            CFLAGS="-arch arm64 -mmacosx-version-min=10.12" \
            CXXFLAGS="-arch arm64 -mmacosx-version-min=10.12" \
            LDFLAGS="-arch arm64 -mmacosx-version-min=10.12"
make clean && make

# 2. Création du bundle
mkdir -p build/BUTT.app/Contents/{MacOS,Frameworks,Resources}
cp src/butt build/BUTT.app/Contents/MacOS/BUTT
chmod +x build/BUTT.app/Contents/MacOS/BUTT

# 3. Collection des dépendances
./scripts/collect_dependencies.sh build/BUTT.app/Contents/MacOS/BUTT build/BUTT.app/Contents/Frameworks

# 4. Création du DMG
hdiutil create -srcfolder build/BUTT.app \
               -volname "BUTT-1.45.0-ARM64" \
               -format UDZO \
               build/BUTT-1.45.0-ARM64-macOS-StereoTool.dmg
```

## 🧪 Tests du Bundle

### Test automatique complet
```bash
./scripts/test_bundle.sh build/BUTT.app --verbose
```

### Tests manuels

#### 1. Vérification de l'architecture
```bash
lipo -info build/BUTT.app/Contents/MacOS/BUTT
```

#### 2. Vérification des dépendances
```bash
otool -L build/BUTT.app/Contents/MacOS/BUTT
```

#### 3. Test de lancement
```bash
# Test basique
open build/BUTT.app

# Test avec debug
BUTT_DEBUG=1 build/BUTT.app/Contents/MacOS/BUTT --version
```

#### 4. Vérification StereoTool
```bash
# Vérifier le chargement de StereoTool
BUTT_DEBUG=1 build/BUTT.app/Contents/MacOS/BUTT --version 2>&1 | grep -i stereotool
```

## 📦 Structure du Bundle

```
BUTT.app/
├── Contents/
│   ├── Info.plist                    # Métadonnées de l'application
│   ├── MacOS/
│   │   └── BUTT                      # Exécutable principal
│   ├── Frameworks/                   # Toutes les dépendances
│   │   ├── libStereoTool64.dylib    # StereoTool SDK
│   │   ├── libfltk.1.4.dylib        # FLTK
│   │   ├── libportaudio.2.dylib     # PortAudio
│   │   ├── libmp3lame.0.dylib       # LAME
│   │   ├── libvorbis.0.dylib        # Vorbis
│   │   ├── libogg.0.dylib           # Ogg
│   │   ├── libopus.0.dylib          # Opus
│   │   ├── libFLAC.12.dylib         # FLAC
│   │   └── ... (autres dépendances)
│   └── Resources/                    # Ressources de l'application
│       ├── butt.icns                # Icône
│       ├── README.txt               # Documentation
│       ├── LICENSE.txt              # Licence
│       └── DISTRIBUTION_NOTICE.txt  # Notice de distribution
```

## 🔧 Configuration Avancée

### Variables d'environnement

```bash
# Architecture cible
export ARCH=arm64  # ou x86_64

# Nettoyage du build
export CLEAN_BUILD=true

# Création du DMG
export CREATE_DMG=true

# Signature du code
export SIGN_CODE=false  # true pour signature
```

### Options du script de build

```bash
./scripts/build_universal_dmg.sh [options]

Options:
  --arch ARCH       Architecture cible (arm64, x86_64) [défaut: arm64]
  --no-clean        Ne pas nettoyer le build précédent
  --no-dmg          Ne pas créer de DMG
  --sign            Signer le code (nécessite certificat Developer ID)
  --help            Afficher l'aide
```

## 🚨 Résolution de Problèmes

### Problème: StereoTool non chargé

**Symptômes:**
```
StereoTool: Could not load library: dlopen failed
```

**Solutions:**
1. Vérifier la présence de la librairie:
   ```bash
   ls -la build/BUTT.app/Contents/Frameworks/libStereoTool64.dylib
   ```

2. Vérifier les chemins de dépendances:
   ```bash
   otool -L build/BUTT.app/Contents/MacOS/BUTT | grep StereoTool
   ```

3. Corriger manuellement si nécessaire:
   ```bash
   install_name_tool -change "/path/to/libStereoTool64.dylib" \
                     "@executable_path/../Frameworks/libStereoTool64.dylib" \
                     build/BUTT.app/Contents/MacOS/BUTT
   ```

### Problème: Dépendances non-résolues

**Symptômes:**
```
dyld: Library not loaded: @rpath/libfltk.1.4.dylib
```

**Solutions:**
1. Collecter les dépendances manquantes:
   ```bash
   ./scripts/collect_dependencies.sh build/BUTT.app/Contents/MacOS/BUTT \
                                    build/BUTT.app/Contents/Frameworks
   ```

2. Vérifier les chemins:
   ```bash
   otool -L build/BUTT.app/Contents/MacOS/BUTT
   ```

### Problème: Application ne se lance pas

**Symptômes:**
- L'application ne répond pas
- Crash au démarrage

**Solutions:**
1. Vérifier les permissions:
   ```bash
   chmod +x build/BUTT.app/Contents/MacOS/BUTT
   ```

2. Tester en ligne de commande:
   ```bash
   build/BUTT.app/Contents/MacOS/BUTT --version
   ```

3. Vérifier les logs système:
   ```bash
   log show --predicate 'process == "BUTT"' --last 1m
   ```

## 📋 Checklist de Distribution

Avant de distribuer le DMG:

- [ ] **Architecture correcte**
  - [ ] ARM64 pour Mac Apple Silicon
  - [ ] x86_64 pour Mac Intel
  - [ ] Vérification avec `lipo -info`

- [ ] **Dépendances résolues**
  - [ ] Aucune dépendance non-résolue
  - [ ] StereoTool SDK présent
  - [ ] Toutes les librairies dans Frameworks/

- [ ] **Tests fonctionnels**
  - [ ] Application se lance
  - [ ] StereoTool se charge
  - [ ] Interface utilisateur fonctionne
  - [ ] Streaming audio fonctionne
  - [ ] AES67 fonctionne (si activé)

- [ ] **Ressources complètes**
  - [ ] Icône présente
  - [ ] Documentation incluse
  - [ ] Notice de distribution

- [ ] **Tests sur machines cibles**
  - [ ] Test sur Mac sans SDK StereoTool
  - [ ] Test sur Mac sans dépendances externes
  - [ ] Test sur différentes versions macOS

## 🎯 Optimisations de Performance

### Réduction de la taille du DMG

```bash
# Compression maximale
hdiutil create -srcfolder build/BUTT.app \
               -volname "BUTT-1.45.0" \
               -format UDZO \
               -imagekey zlib-level=9 \
               -imagekey bzip2-level=9 \
               build/BUTT-1.45.0.dmg
```

### Optimisation des dépendances

```bash
# Supprimer les symboles de debug
strip -S build/BUTT.app/Contents/MacOS/BUTT
strip -S build/BUTT.app/Contents/Frameworks/*.dylib

# Optimiser les librairies
for lib in build/BUTT.app/Contents/Frameworks/*.dylib; do
    install_name_tool -id "@executable_path/../Frameworks/$(basename "$lib")" "$lib"
done
```

## 📊 Métriques de Qualité

### Taille typique du bundle
- **Bundle seul**: ~50-80 MB
- **DMG compressé**: ~30-50 MB
- **Dépendances**: ~20-30 MB

### Temps de construction
- **Compilation**: 2-5 minutes
- **Collection dépendances**: 1-2 minutes
- **Création DMG**: 30-60 secondes
- **Total**: 5-10 minutes

### Compatibilité
- **macOS minimum**: 10.12 (Sierra)
- **Architectures**: ARM64, x86_64
- **Processeurs**: Apple Silicon, Intel

## 🔄 Mise à Jour

### Processus de mise à jour

1. **Modifier la version**:
   ```bash
   # Dans build_universal_dmg.sh
   VERSION="1.46.0"
   ```

2. **Reconstruire**:
   ```bash
   ./scripts/build_universal_dmg.sh --arch arm64
   ```

3. **Tester**:
   ```bash
   ./scripts/test_bundle.sh build/BUTT.app
   ```

4. **Distribuer**:
   - Renommer le DMG avec la nouvelle version
   - Mettre à jour la documentation
   - Notifier les utilisateurs

## 📞 Support

### Logs de debug

```bash
# Activer le debug StereoTool
export BUTT_DEBUG=1

# Activer le debug audio
export BUTT_AUDIO_DEBUG=1

# Lancer avec logs
./BUTT.app/Contents/MacOS/BUTT 2>&1 | tee butt_debug.log
```

### Informations système

```bash
# Informations macOS
sw_vers

# Informations processeur
uname -m

# Informations mémoire
system_profiler SPHardwareDataType
```

### Contact

Pour le support technique:
- Vérifier d'abord ce guide
- Consulter les logs de debug
- Fournir les informations système
- Décrire précisément le problème

---

**Note**: Ce guide est optimisé pour la distribution privée. Pour la distribution publique via l'App Store, des étapes supplémentaires de signature et notarisation sont requises.
