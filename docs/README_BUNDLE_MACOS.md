# 🍎 Bundle macOS BUTT avec StereoTool SDK

## 🎯 Résumé de la Solution

Cette solution permet de créer un **bundle macOS indépendant** de BUTT avec StereoTool SDK intégré. Le bundle résultant :

- ✅ **Charge les librairies depuis son propre dossier `Frameworks/`**
- ✅ **Fonctionne sur n'importe quel Mac sans dépendances externes**
- ✅ **Inclut l'interface StereoTool complète dans l'onglet DSP**
- ✅ **Peut être distribué via DMG**
- ✅ **Résout le problème de chemins relatifs de développement**

## 🚀 Commande Rapide

Pour créer le bundle complet en une seule commande :

```bash
cd butt-1.45.0
make -f Makefile.bundle dmg
```

Le DMG sera créé dans `build/BUTT-1.45.0-macOS-StereoTool.dmg` et sera prêt pour la distribution !

## 📁 Fichiers Ajoutés

### 1️⃣ Modifications du Code Source

- **`src/stereo_tool.cpp`** : Modifié pour chercher d'abord dans le bundle's Framework directory
  - Ajout de la fonction `get_bundle_framework_path()`
  - Modification de `load_stereo_tool_library()` pour prioriser le bundle
  - Ajout de `#include <mach-o/dyld.h>` pour macOS

### 2️⃣ Scripts d'Automatisation

- **`build_macos_bundle.sh`** : Script complet pour créer le bundle
  - Création de la structure du bundle
  - Copie des librairies et ressources
  - Correction des liens dynamiques avec `install_name_tool`
  - Création du DMG distributible

- **`Makefile.bundle`** : Makefile spécialisé pour la création du bundle
  - Cibles : `compile`, `bundle`, `dmg`, `test`, `install`, `clean`
  - Automatisation complète du processus

### 3️⃣ Documentation

- **`GUIDE_BUNDLE_MACOS.md`** : Guide complet avec méthodes automatique et manuelle
- **`README_BUNDLE_MACOS.md`** : Ce fichier de résumé

## 🔧 Modifications Techniques

### Chargement des Librairies

**Avant :**
```cpp
const char* lib_paths[] = {
    "../libStereoTool_992/libStereoTool64.dylib",  // Chemin relatif de développement
    "/usr/local/lib/libStereoTool.dylib",          // Chemin système
    NULL
};
```

**Après :**
```cpp
// Détection automatique du bundle
char* bundle_fw_path = get_bundle_framework_path();
char bundle_lib_path[1024];
if (bundle_fw_path) {
    snprintf(bundle_lib_path, sizeof(bundle_lib_path), "%s/libStereoTool64.dylib", bundle_fw_path);
}

const char* lib_paths[] = {
    bundle_fw_path ? bundle_lib_path : NULL,       // Bundle PRIORITAIRE
    "../libStereoTool_992/libStereoTool64.dylib",  // Développement
    "/usr/local/lib/libStereoTool.dylib",          // Système
    NULL
};
```

### Liens Dynamiques

Le script utilise `install_name_tool` pour corriger tous les liens :

```bash
# Correction de l'ID de la librairie
install_name_tool -id "@executable_path/../Frameworks/libStereoTool64.dylib" \
    build/BUTT.app/Contents/Frameworks/libStereoTool64.dylib

# Correction des dépendances de l'exécutable
install_name_tool -change "../libStereoTool_992/libStereoTool64.dylib" \
    "@executable_path/../Frameworks/libStereoTool64.dylib" \
    build/BUTT.app/Contents/MacOS/BUTT
```

## 📦 Structure du Bundle Final

```
build/BUTT.app/
├── Contents/
│   ├── MacOS/
│   │   └── BUTT                    # Exécutable principal (liens corrigés)
│   ├── Frameworks/
│   │   └── libStereoTool64.dylib   # Librairie StereoTool (ID corrigé)
│   ├── Resources/
│   │   ├── butt.icns               # Icône de l'application
│   │   ├── README                  # Documentation
│   │   ├── ChangeLog.txt           # Historique des versions
│   │   └── LICENSE.txt             # Licence
│   └── Info.plist                  # Métadonnées du bundle
```

## 🎨 Fonctionnalités Incluses

Le bundle contient l'interface StereoTool complète développée précédemment :

- **Contrôles Stream/Record/Replace DSP** : Activation sélective des fonctionnalités
- **Gestion des licences** : Test sécurisé sans segmentation fault
- **Gestion des presets** : Chargement/sauvegarde des fichiers .sts
- **Affichage temps réel** : Statut de connexion et latence
- **Interface responsive** : Fenêtre optimisée pour tous les contrôles

## 🧪 Tests et Validation

### Tests Automatiques

```bash
# Vérifier la structure
make -f Makefile.bundle test

# Vérifier les dépendances
otool -L build/BUTT.app/Contents/MacOS/BUTT
otool -L build/BUTT.app/Contents/Frameworks/libStereoTool64.dylib
```

### Tests Fonctionnels

1. **Lancement** : `open build/BUTT.app`
2. **Interface StereoTool** : Vérifier l'onglet DSP
3. **Chargement des presets** : Tester les boutons Load/Save
4. **Traitement audio** : Vérifier streaming et enregistrement

## 🐛 Dépannage

### Problèmes Courants

1. **"Librairie StereoTool introuvable"**
   - Vérifier : `ls -la build/BUTT.app/Contents/Frameworks/`
   - Solution : Relancer le script de création

2. **"Application endommagée"**
   - Solution : `sudo xattr -rd com.apple.quarantine build/BUTT.app`

3. **Crash au lancement**
   - Vérifier les logs dans Console.app
   - Vérifier les dépendances avec `otool -L`

## 📈 Avantages de cette Solution

### ✅ Indépendance
- Aucune dépendance externe requise
- Fonctionne sur n'importe quel Mac compatible

### ✅ Portabilité
- Bundle auto-suffisant
- DMG distributible facilement

### ✅ Compatibilité
- Supporte le développement local ET la distribution
- Chemins de recherche intelligents

### ✅ Automatisation
- Création du bundle en une commande
- Correction automatique des liens
- Génération du DMG incluse

## 🔮 Utilisation Future

### Mise à jour des Librairies
Pour mettre à jour StereoTool SDK :
1. Remplacer la librairie dans `libStereoTool_992/` ou `libStereoTool_1051/`
2. Relancer : `make -f Makefile.bundle dmg`

### Personnalisation
- Modifier `build_macos_bundle.sh` pour des besoins spécifiques
- Ajuster les chemins dans `Makefile.bundle`
- Personnaliser `Info.plist` pour la signature

## 🎉 Conclusion

Cette solution résout complètement le problème de distribution macOS :

1. **Problème initial** : Application charge depuis `libStereoTool_992/`
2. **Solution** : Bundle auto-suffisant avec librairies intégrées
3. **Résultat** : DMG distributible fonctionnant sur n'importe quel Mac

Le bundle créé est **professionnel**, **indépendant** et **prêt pour la distribution** ! 🚀

---

**Commande finale :**
```bash
cd butt-1.45.0
make -f Makefile.bundle dmg
```

**Résultat :** `build/BUTT-1.45.0-macOS-StereoTool.dmg` prêt à distribuer ! 🎯 