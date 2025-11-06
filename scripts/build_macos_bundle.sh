#!/bin/bash

# Script pour créer un bundle macOS indépendant de BUTT avec StereoTool SDK
# Auteur: Script automatisé pour intégration StereoTool
# Version: 1.0

set -e # Arrêter en cas d'erreur

echo "🎯 Création du bundle macOS BUTT avec StereoTool SDK..."

# Configuration
APP_NAME="BUTT"
BUNDLE_NAME="BUTT.app"
VERSION="1.45.0"
BUNDLE_ID="de.danielnoethen.butt"

# Répertoires
PROJECT_DIR="$(pwd)"
BUILD_DIR="$PROJECT_DIR/build"
BUNDLE_DIR="$BUILD_DIR/$BUNDLE_NAME"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# Nettoyage
echo "🧹 Nettoyage des builds précédents..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Création de la structure du bundle
echo "📁 Création de la structure du bundle..."
mkdir -p "$MACOS_DIR"
mkdir -p "$FRAMEWORKS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copie de l'exécutable
echo "📦 Copie de l'exécutable..."
if [ -f "src/butt" ]; then
    cp "src/butt" "$MACOS_DIR/$APP_NAME"
    chmod +x "$MACOS_DIR/$APP_NAME"
else
    echo "❌ Erreur: Exécutable 'src/butt' introuvable. Compilez d'abord avec 'make'."
    exit 1
fi

# Copie des librairies StereoTool
echo "📚 Copie des librairies StereoTool..."
STEREO_TOOL_LIBS=(
    "../libStereoTool_992/libStereoTool64.dylib"
    "../libStereoTool_1051/lib/macOS/Universal/64/libStereoTool_64.dylib"
)

COPIED_LIB=""
for lib_path in "${STEREO_TOOL_LIBS[@]}"; do
    if [ -f "$lib_path" ]; then
        echo "✅ Copie de $lib_path..."
        cp "$lib_path" "$FRAMEWORKS_DIR/libStereoTool64.dylib"
        COPIED_LIB="$lib_path"
        break
    fi
done

if [ -z "$COPIED_LIB" ]; then
    echo "❌ Erreur: Aucune librairie StereoTool trouvée."
    echo "Cherché dans:"
    for lib_path in "${STEREO_TOOL_LIBS[@]}"; do
        echo "  - $lib_path"
    done
    exit 1
fi

# Copie des ressources
echo "🎨 Copie des ressources..."
if [ -f "icons/butt.icns" ]; then
    cp "icons/butt.icns" "$RESOURCES_DIR/"
else
    echo "⚠️  Avertissement: Icône introuvable"
fi

# Copie des fichiers de documentation
if [ -f "README" ]; then
    cp "README" "$RESOURCES_DIR/"
fi
if [ -f "ChangeLog" ]; then
    cp "ChangeLog" "$RESOURCES_DIR/ChangeLog.txt"
fi
if [ -f "COPYING" ]; then
    cp "COPYING" "$RESOURCES_DIR/LICENSE.txt"
fi

# Création du fichier Info.plist
echo "📝 Création du fichier Info.plist..."
cat > "$CONTENTS_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>butt.icns</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.12</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>BUTT nécessite l'accès au microphone pour diffuser de l'audio en direct.</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.music</string>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeExtensions</key>
            <array>
                <string>buttrc</string>
            </array>
            <key>CFBundleTypeName</key>
            <string>BUTT Configuration</string>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
        </dict>
    </array>
</dict>
</plist>
EOF

# Résolution des dépendances avec otool et install_name_tool
echo "🔗 Résolution des dépendances dynamiques..."

# Fonction pour traiter les dépendances
fix_dependencies() {
    local file="$1"
    local base_name=$(basename "$file")
    
    echo "🔍 Analyse des dépendances de $base_name..."
    
    # Lister les dépendances
    otool -L "$file" | grep -E "(\.dylib|\.framework)" | grep -v "^$file:" | while read -r dep; do
        # Nettoyer la ligne otool
        dep_path=$(echo "$dep" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]].*//')
        dep_name=$(basename "$dep_path")
        
        # Ignorer les librairies système
        if [[ "$dep_path" =~ ^/System/ ]] || [[ "$dep_path" =~ ^/usr/lib/ ]]; then
            continue
        fi
        
        # Traiter les librairies non-système
        if [[ "$dep_path" =~ libStereoTool.*\.dylib ]]; then
            echo "🔄 Correction du lien StereoTool: $dep_path -> @executable_path/../Frameworks/libStereoTool64.dylib"
            install_name_tool -change "$dep_path" "@executable_path/../Frameworks/libStereoTool64.dylib" "$file"
        elif [[ ! "$dep_path" =~ ^@(executable_path|loader_path|rpath) ]]; then
            echo "⚠️  Dépendance externe détectée: $dep_path"
        fi
    done
}

# Traiter l'exécutable principal
fix_dependencies "$MACOS_DIR/$APP_NAME"

# Traiter les librairies dans Frameworks
for lib in "$FRAMEWORKS_DIR"/*.dylib; do
    if [ -f "$lib" ]; then
        # Fixer l'ID de la librairie
        lib_name=$(basename "$lib")
        echo "🆔 Correction de l'ID de $lib_name..."
        install_name_tool -id "@executable_path/../Frameworks/$lib_name" "$lib"
        
        # Fixer les dépendances
        fix_dependencies "$lib"
    fi
done

# Vérification finale
echo "🔎 Vérification finale des liens..."
echo "Dépendances de l'exécutable principal:"
otool -L "$MACOS_DIR/$APP_NAME" | grep -E "(\.dylib|\.framework)" | head -10

echo "Dépendances des librairies StereoTool:"
for lib in "$FRAMEWORKS_DIR"/*.dylib; do
    if [ -f "$lib" ]; then
        echo "$(basename "$lib"):"
        otool -L "$lib" | grep -E "(\.dylib|\.framework)" | head -5
    fi
done

# Création du DMG
echo "💿 Création du DMG..."
DMG_NAME="BUTT-$VERSION-macOS-StereoTool"
DMG_PATH="$BUILD_DIR/$DMG_NAME.dmg"

# Supprimer le DMG existant s'il existe
rm -f "$DMG_PATH"

# Créer le DMG
hdiutil create -srcfolder "$BUNDLE_DIR" -volname "$DMG_NAME" -format UDZO -imagekey zlib-level=9 "$DMG_PATH"

echo "✅ Bundle macOS créé avec succès!"
echo "📁 Bundle: $BUNDLE_DIR"
echo "💿 DMG: $DMG_PATH"
echo ""
echo "🎉 Le bundle est maintenant indépendant et peut être distribué!"
echo ""
echo "📋 Tests recommandés:"
echo "1. Testez le bundle sur une machine sans SDK StereoTool"
echo "2. Vérifiez que l'interface StereoTool fonctionne"
echo "3. Testez le chargement des presets"
echo "4. Vérifiez les fonctionnalités de streaming et enregistrement"
echo ""
echo "🚀 Pour installer: Montez le DMG et glissez BUTT.app dans Applications" 