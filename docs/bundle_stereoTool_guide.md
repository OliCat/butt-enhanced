# 🎵 Guide de création d'un bundle macOS pour BUTT avec StereoTool

## 🚀 Problème résolu

Le problème était que la bibliothèque StereoTool est chargée dynamiquement via `dlopen()` avec des chemins relatifs qui ne fonctionnent pas dans un bundle macOS.

## 📋 Solutions disponibles

### 1. **Solution recommandée : Patch permanent**

**Fichier :** `apply_bundle_patch.sh`

```bash
./apply_bundle_patch.sh
```

**Avantages :**
- ✅ Modifie le code source pour supporter nativement les bundles macOS
- ✅ Ajoute la recherche automatique dans `Contents/Frameworks/`
- ✅ Support des variables d'environnement
- ✅ Compatible avec tous les scripts de bundle existants

**Processus :**
1. Applique le patch au code source
2. Recompile automatiquement le projet
3. Le binaire supporte maintenant les bundles macOS

### 2. **Solution simple : Variables d'environnement**

**Fichier :** `create_app_bundle_simple.sh`

```bash
./create_app_bundle_simple.sh [version]
```

**Avantages :**
- ✅ Pas de modification du code source
- ✅ Utilise un script wrapper
- ✅ Définit `DYLD_LIBRARY_PATH` et `STEREO_TOOL_LIB_PATH`
- ✅ Rapide et simple

**Processus :**
1. Crée un bundle avec script wrapper
2. Le wrapper définit les variables d'environnement
3. Lance le binaire original

### 3. **Solution avancée : Recompilation intégrée**

**Fichier :** `create_app_bundle_stereoTool.sh`

```bash
./create_app_bundle_stereoTool.sh [version]
```

**Avantages :**
- ✅ Modifie et recompile automatiquement
- ✅ Crée un binaire spécifique au bundle
- ✅ Gestion complète des dépendances

**Processus :**
1. Copie et modifie le code source
2. Recompile spécifiquement pour le bundle
3. Intègre le binaire modifié

## 🎯 Recommandation d'utilisation

### Pour un usage unique :
```bash
./create_app_bundle_simple.sh
```

### Pour un usage régulier :
```bash
./apply_bundle_patch.sh
# Puis utiliser n'importe quel script de bundle
./create_app_bundle.sh
```

## 📁 Structure du bundle créé

```
BUTT.app/
├── Contents/
│   ├── Info.plist
│   ├── MacOS/
│   │   ├── BUTT (wrapper ou binaire)
│   │   └── BUTT_binary (si wrapper)
│   ├── Resources/
│   │   ├── butt.icns
│   │   ├── README.txt
│   │   ├── LICENSE.txt
│   │   └── Version.txt
│   └── Frameworks/
│       └── libStereoTool64.dylib
```

## 🔧 Test du bundle

### Test simple :
```bash
open BUTT.app
```

### Test avec debug :
```bash
BUTT_DEBUG=1 open BUTT.app
```

### Test script inclus :
```bash
./BUTT.app/Contents/Resources/test_bundle.sh
```

## 🚀 Création du DMG

Après avoir créé le bundle avec n'importe quelle méthode :

```bash
./create_dmg_with_bundle.sh [version]
```

## 🧪 Vérification du fonctionnement

### 1. Vérifier la présence de la bibliothèque :
```bash
ls -la BUTT.app/Contents/Frameworks/libStereoTool64.dylib
```

### 2. Vérifier les dépendances :
```bash
otool -L BUTT.app/Contents/MacOS/BUTT
```

### 3. Tester le chargement :
```bash
# Avec debug
BUTT_DEBUG=1 ./BUTT.app/Contents/MacOS/BUTT --version
```

## 💡 Notes importantes

### Variables d'environnement supportées :
- `STEREO_TOOL_LIB_PATH` : Chemin spécifique vers la bibliothèque
- `DYLD_LIBRARY_PATH` : Chemin de recherche des bibliothèques
- `BUTT_DEBUG` : Active les messages de debug

### Ordre de recherche des bibliothèques :
1. `Contents/Frameworks/libStereoTool64.dylib` (bundle)
2. `$STEREO_TOOL_LIB_PATH` (variable d'environnement)
3. `../libStereoTool_992/libStereoTool64.dylib` (relatif)
4. `/usr/local/lib/libStereoTool.dylib` (système)
5. `/opt/homebrew/lib/libStereoTool.dylib` (homebrew)

## 🔄 Processus complet recommandé

```bash
# 1. Appliquer le patch permanent (une seule fois)
./apply_bundle_patch.sh

# 2. Créer le bundle
./create_app_bundle.sh

# 3. Créer le DMG
./create_dmg_with_bundle.sh

# 4. Tester
open BUTT.app
```

## 🎉 Résultat final

Un bundle macOS complet avec :
- ✅ StereoTool intégré et fonctionnel
- ✅ Toutes les dépendances incluses
- ✅ Interface utilisateur native macOS
- ✅ Prêt pour distribution
- ✅ Compatible avec toutes les versions de macOS supportées

---

*Ce guide couvre toutes les méthodes pour créer un bundle macOS avec StereoTool intégré. La solution recommandée est d'utiliser le patch permanent pour un support natif optimal.* 