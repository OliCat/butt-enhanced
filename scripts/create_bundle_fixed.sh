#!/bin/bash
#
# Script pour créer un bundle macOS autonome de BUTT
# Corrige le problème de signature et embarque toutes les dépendances
#

set -e

echo "🎯 Création du bundle BUTT autonome..."

# Configuration
APP_NAME="BUTT"
BUNDLE_NAME="BUTT.app"
VERSION="1.45.0-AES67"

# Répertoires
PROJECT_DIR="$(pwd)"
BUILD_DIR="$PROJECT_DIR/build"
BUNDLE_DIR="$BUILD_DIR/$BUNDLE_NAME"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# Vérifier que l'exécutable existe
if [ ! -f "src/butt" ]; then
    echo "❌ Erreur: src/butt n'existe pas. Compilez d'abord avec 'make'."
    exit 1
fi

# Nettoyage
echo "🧹 Nettoyage..."
rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR" "$FRAMEWORKS_DIR" "$RESOURCES_DIR"

# Copie de l'exécutable
echo "📦 Copie de l'exécutable..."
cp "src/butt" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

# Fonction pour copier une dylib et ses dépendances
copy_dylib() {
    local lib_path="$1"
    local lib_name=$(basename "$lib_path")
    local dest="$FRAMEWORKS_DIR/$lib_name"
    
    # Si déjà copiée, skip
    if [ -f "$dest" ]; then
        return
    fi
    
    # Ignorer les librairies système
    if [[ "$lib_path" =~ ^/System/ ]] || [[ "$lib_path" =~ ^/usr/lib/ ]]; then
        return
    fi
    
    # Copier la dylib
    if [ -f "$lib_path" ]; then
        echo "  📚 Copie: $lib_name"
        cp "$lib_path" "$dest"
        chmod +w "$dest"
        
        # Copier récursivement les dépendances
        otool -L "$lib_path" | grep -v "^$lib_path:" | awk '{print $1}' | while read dep; do
            if [[ ! "$dep" =~ ^/System/ ]] && [[ ! "$dep" =~ ^/usr/lib/ ]] && [[ ! "$dep" =~ ^@ ]]; then
                copy_dylib "$dep"
            fi
        done
    fi
}

# Collecter toutes les dépendances
echo "🔗 Collecte des dépendances..."
otool -L "src/butt" | grep -v "^src/butt:" | awk '{print $1}' | while read dep; do
    copy_dylib "$dep"
done

# Copier libStereoTool64.dylib si elle existe
if [ -f "libStereoTool64.dylib" ]; then
    echo "  📚 Copie: libStereoTool64.dylib"
    cp "libStereoTool64.dylib" "$FRAMEWORKS_DIR/"
    chmod +w "$FRAMEWORKS_DIR/libStereoTool64.dylib"
fi

# Relinker l'exécutable principal
echo "🔗 Relinking de l'exécutable..."
for lib in "$FRAMEWORKS_DIR"/*.dylib; do
    lib_name=$(basename "$lib")
    
    # Obtenir le chemin original de la lib dans l'exécutable
    orig_path=$(otool -L "$MACOS_DIR/$APP_NAME" | grep "$lib_name" | awk '{print $1}' || true)
    
    if [ -n "$orig_path" ]; then
        echo "  🔄 $lib_name: $orig_path -> @executable_path/../Frameworks/$lib_name"
        install_name_tool -change "$orig_path" "@executable_path/../Frameworks/$lib_name" "$MACOS_DIR/$APP_NAME"
    fi
done

# Fixer l'ID et les dépendances de chaque dylib
echo "🔧 Correction des dylibs..."
for lib in "$FRAMEWORKS_DIR"/*.dylib; do
    lib_name=$(basename "$lib")
    
    # Fixer l'ID
    install_name_tool -id "@executable_path/../Frameworks/$lib_name" "$lib"
    
    # Fixer les dépendances internes
    otool -L "$lib" | grep -v "^$lib:" | awk '{print $1}' | while read dep; do
        dep_name=$(basename "$dep")
        dep_file="$FRAMEWORKS_DIR/$dep_name"
        
        if [ -f "$dep_file" ]; then
            echo "  🔄 $lib_name dépend de $dep_name"
            install_name_tool -change "$dep" "@executable_path/../Frameworks/$dep_name" "$lib"
        fi
    done
done

# Copier les ressources
echo "🎨 Copie des ressources..."
[ -f "icons/butt.icns" ] && cp "icons/butt.icns" "$RESOURCES_DIR/"
[ -f "README" ] && cp "README" "$RESOURCES_DIR/"
[ -f "ChangeLog" ] && cp "ChangeLog" "$RESOURCES_DIR/ChangeLog.txt"
[ -f "COPYING" ] && cp "COPYING" "$RESOURCES_DIR/LICENSE.txt"

# Créer Info.plist
echo "📝 Création de Info.plist..."
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
    <string>de.danielnoethen.butt</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>BUTT requires microphone access for audio streaming.</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.music</string>
</dict>
</plist>
EOF

# Supprimer les anciennes signatures
echo "🗑️  Suppression des anciennes signatures..."
find "$BUNDLE_DIR" -name "_CodeSignature" -exec rm -rf {} \; 2>/dev/null || true

# Re-signer adhoc (sans certificat développeur)
echo "✍️  Signature adhoc du bundle..."
codesign --force --deep --sign - "$BUNDLE_DIR"

# Vérification
echo ""
echo "🔍 Vérification finale..."
echo "Signature:"
codesign -dvv "$BUNDLE_DIR" 2>&1 | grep -E "Signature|Identifier"
echo ""
echo "Dépendances de l'exécutable:"
otool -L "$MACOS_DIR/$APP_NAME" | grep -E "\.dylib" | head -5
echo ""
echo "Librairies embarquées:"
ls -lh "$FRAMEWORKS_DIR" | grep "\.dylib" | wc -l | xargs echo "  Nombre de dylibs:"

echo ""
echo "✅ Bundle créé avec succès!"
echo "📁 Emplacement: $BUNDLE_DIR"
echo ""
echo "🧪 Test rapide:"
echo "   open $BUNDLE_DIR"
echo ""
echo "Si l'app se ferme immédiatement, vérifiez les logs:"
echo "   Console.app > Rapports de plantage"
echo "   ou: log show --predicate 'process == \"BUTT\"' --last 1m"

