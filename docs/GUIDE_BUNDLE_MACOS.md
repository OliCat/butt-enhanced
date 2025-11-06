# 🍎 Guide Bundle macOS - BUTT avec StereoTool SDK

Ce guide explique comment créer un bundle macOS **indépendant** et **distributible** de BUTT avec StereoTool SDK intégré.

## 🎯 Objectif

Créer un bundle macOS qui :
- ✅ Charge les librairies StereoTool depuis son propre dossier `Frameworks/`
- ✅ Fonctionne sur n'importe quel Mac sans dépendances externes
- ✅ Peut être distribué via DMG
- ✅ Inclut l'interface StereoTool complète

## 📋 Prérequis

- macOS 10.12 ou plus récent
- Xcode Command Line Tools installés
- BUTT compilé avec succès
- StereoTool SDK (version 9.92 ou 10.51)

## 🚀 Méthode 1 : Création automatique (Recommandée)

### 1️⃣ Préparation

```bash
# Naviguer dans le répertoire BUTT
cd butt-1.45.0

# Vérifier que l'exécutable est compilé
ls -la src/butt

# Vérifier que les librairies StereoTool sont présentes
ls -la ../libStereoTool_992/libStereoTool64.dylib
# OU
ls -la ../libStereoTool_1051/lib/macOS/Universal/64/libStereoTool_64.dylib
```

### 2️⃣ Création du bundle

```bash
# Méthode recommandée : Makefile
make -f Makefile.bundle dmg

# OU méthode directe : Script
./build_macos_bundle.sh
```

### 3️⃣ Résultat

```
build/
├── BUTT.app/                    # Bundle prêt à utiliser
│   ├── Contents/
│   │   ├── MacOS/
│   │   │   └── BUTT             # Exécutable principal
│   │   ├── Frameworks/
│   │   │   └── libStereoTool64.dylib  # Librairie StereoTool
│   │   ├── Resources/
│   │   │   ├── butt.icns
│   │   │   └── ...
│   │   └── Info.plist
└── BUTT-1.45.0-macOS-StereoTool.dmg  # DMG distributible
```

## 🛠️ Méthode 2 : Création manuelle

### 1️⃣ Compilation

```bash
cd butt-1.45.0
make clean
make
```

### 2️⃣ Création de la structure

```bash
# Créer les répertoires
mkdir -p build/BUTT.app/Contents/{MacOS,Frameworks,Resources}

# Copier l'exécutable
cp src/butt build/BUTT.app/Contents/MacOS/BUTT
chmod +x build/BUTT.app/Contents/MacOS/BUTT

# Copier les librairies StereoTool
cp ../libStereoTool_992/libStereoTool64.dylib build/BUTT.app/Contents/Frameworks/

# Copier les ressources
cp icons/butt.icns build/BUTT.app/Contents/Resources/
```

### 3️⃣ Création du Info.plist

```bash
cat > build/BUTT.app/Contents/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>BUTT</string>
    <key>CFBundleIconFile</key>
    <string>butt.icns</string>
    <key>CFBundleIdentifier</key>
    <string>de.danielnoethen.butt</string>
    <key>CFBundleName</key>
    <string>BUTT</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.45.0</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>BUTT nécessite l'accès au microphone pour diffuser de l'audio en direct.</string>
</dict>
</plist>
EOF
```

### 4️⃣ Correction des liens dynamiques

```bash
# Fixer l'ID de la librairie StereoTool
install_name_tool -id "@executable_path/../Frameworks/libStereoTool64.dylib" \
    build/BUTT.app/Contents/Frameworks/libStereoTool64.dylib

# Fixer les dépendances de l'exécutable
install_name_tool -change "../libStereoTool_992/libStereoTool64.dylib" \
    "@executable_path/../Frameworks/libStereoTool64.dylib" \
    build/BUTT.app/Contents/MacOS/BUTT
```

### 5️⃣ Création du DMG

```bash
hdiutil create -srcfolder build/BUTT.app -volname "BUTT-1.45.0-macOS-StereoTool" \
    -format UDZO -imagekey zlib-level=9 build/BUTT-1.45.0-macOS-StereoTool.dmg
```

## 🔍 Vérification

### Tests de base

```bash
# Vérifier la structure du bundle
ls -la build/BUTT.app/Contents/
ls -la build/BUTT.app/Contents/Frameworks/

# Vérifier les dépendances
otool -L build/BUTT.app/Contents/MacOS/BUTT | grep -E "(\.dylib|\.framework)"
otool -L build/BUTT.app/Contents/Frameworks/libStereoTool64.dylib | grep -E "(\.dylib|\.framework)"
```

### Tests fonctionnels

```bash
# Tester le lancement
open build/BUTT.app

# Vérifier les logs
tail -f /var/log/system.log | grep BUTT
```

## 🎯 Utilisation avec Makefile

### Commandes disponibles

```bash
# Aide
make -f Makefile.bundle help

# Compilation uniquement
make -f Makefile.bundle compile

# Création du bundle
make -f Makefile.bundle bundle

# Création du DMG
make -f Makefile.bundle dmg

# Tests
make -f Makefile.bundle test

# Installation
make -f Makefile.bundle install

# Nettoyage
make -f Makefile.bundle clean
```

## 🐛 Dépannage

### Problème : "Librairie StereoTool introuvable"

**Symptôme :** L'application ne trouve pas la librairie StereoTool

**Solution :**
1. Vérifier que la librairie est dans `Frameworks/` :
   ```bash
   ls -la build/BUTT.app/Contents/Frameworks/libStereoTool64.dylib
   ```

2. Vérifier les liens dynamiques :
   ```bash
   otool -L build/BUTT.app/Contents/MacOS/BUTT
   ```

3. Corriger les liens si nécessaire :
   ```bash
   install_name_tool -change "ancien_chemin" "@executable_path/../Frameworks/libStereoTool64.dylib" build/BUTT.app/Contents/MacOS/BUTT
   ```

### Problème : "Application endommagée"

**Symptôme :** macOS refuse de lancer l'application

**Solution :**
```bash
# Supprimer les attributs de quarantaine
sudo xattr -rd com.apple.quarantine build/BUTT.app

# Ou signer l'application (nécessite un certificat développeur)
codesign --force --deep --sign - build/BUTT.app
```

### Problème : "Dépendances manquantes"

**Symptôme :** L'application crash au lancement

**Solution :**
1. Lister toutes les dépendances :
   ```bash
   otool -L build/BUTT.app/Contents/MacOS/BUTT
   ```

2. Copier les librairies manquantes dans `Frameworks/`

3. Corriger les liens avec `install_name_tool`

## 📦 Distribution

### Préparation du DMG

```bash
# Créer un DMG avec une belle présentation
hdiutil create -srcfolder build/BUTT.app \
    -volname "BUTT avec StereoTool" \
    -format UDZO -imagekey zlib-level=9 \
    -o "BUTT-1.45.0-macOS-StereoTool.dmg"
```

### Signature (optionnel)

```bash
# Signer le bundle (nécessite un certificat développeur)
codesign --force --deep --sign "Developer ID Application: Votre Nom" build/BUTT.app

# Notariser (nécessite un compte développeur Apple)
xcrun notarytool submit BUTT-1.45.0-macOS-StereoTool.dmg --wait
```

## ✅ Checklist finale

- [ ] Bundle créé avec succès
- [ ] Librairie StereoTool dans `Frameworks/`
- [ ] Liens dynamiques corrigés
- [ ] Application se lance sans erreur
- [ ] Interface StereoTool fonctionnelle
- [ ] Presets chargeables
- [ ] Streaming et enregistrement opérationnels
- [ ] DMG créé et testé
- [ ] Documentation incluse

## 🚀 Commande rapide

Pour créer le bundle complet en une seule commande :

```bash
cd butt-1.45.0
make -f Makefile.bundle dmg
```

Le DMG sera créé dans `build/BUTT-1.45.0-macOS-StereoTool.dmg` et sera prêt pour la distribution !

## 📞 Support

En cas de problème, vérifiez :
1. Les logs d'erreur dans Console.app
2. Les dépendances avec `otool -L`
3. Les permissions avec `ls -la`
4. La structure du bundle avec `find build/BUTT.app -type f`

Le bundle créé est **totalement indépendant** et peut être distribué sur n'importe quel Mac compatible ! 🎉 