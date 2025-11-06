#!/bin/bash

# Script pour compiler BUTT spécifiquement pour Intel x86_64 sur Mac
# Auteur: Assistant pour projet StereoTool SDK
# Version: 1.0

set -e # Arrêter en cas d'erreur

echo "🔧 Compilation BUTT pour Intel x86_64..."
echo "======================================="

# Configuration
ARCH="x86_64"
BUILD_DIR="build-$ARCH"
APP_NAME="BUTT"
BUNDLE_NAME="BUTT-Intel.app"
VERSION="1.45.0"
BUNDLE_ID="de.danielnoethen.butt.intel"

# **FORCER L'UTILISATION DES OUTILS INTEL EN PREMIER**
export PATH="/usr/local/bin:$PATH"
export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/local/share/pkgconfig:$PKG_CONFIG_PATH"

echo "🔍 Vérification des outils Intel..."
echo "fltk-config utilisé: $(which fltk-config)"
echo "Version FLTK: $(fltk-config --version 2>/dev/null || echo 'non trouvé')"

# Test rapide
if [[ "$(which fltk-config)" != "/usr/local/bin/fltk-config" ]]; then
    echo "❌ Erreur: fltk-config Intel non trouvé!"
    echo "Attendu: /usr/local/bin/fltk-config"
    echo "Trouvé: $(which fltk-config)"
    exit 1
fi

# Nettoyage des builds précédents
echo "🧹 Nettoyage des builds précédents..."
rm -rf "$BUILD_DIR"
make clean 2>/dev/null || true

# Configuration pour Intel x86_64
echo "⚙️  Configuration pour Intel x86_64..."
export CC="clang -arch x86_64"
export CXX="clang++ -arch x86_64"
export OBJC="clang -arch x86_64"
export OBJCXX="clang++ -arch x86_64"
export CFLAGS="-arch x86_64 -mmacosx-version-min=10.12"
export CXXFLAGS="-arch x86_64 -mmacosx-version-min=10.12"
export OBJCFLAGS="-arch x86_64 -mmacosx-version-min=10.12"
export OBJCXXFLAGS="-arch x86_64 -mmacosx-version-min=10.12"
export LDFLAGS="-arch x86_64 -mmacosx-version-min=10.12"

# Recherche des dépendances
echo "📦 Recherche des dépendances..."
# Pour Intel, priorité aux bibliothèques Intel de /usr/local
PKG_CONFIG_PATH=""
if [ -d "/usr/local/lib/pkgconfig" ]; then
    PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"
fi
if [ -d "/opt/homebrew/lib/pkgconfig" ]; then
    PKG_CONFIG_PATH="$PKG_CONFIG_PATH:/opt/homebrew/lib/pkgconfig"
fi
export PKG_CONFIG_PATH

# Variables d'environnement pour les bibliothèques Intel
export LIBRARY_PATH="/usr/local/lib:/usr/local/opt/openssl@3/lib:/usr/local/Cellar/gettext/0.25.1/lib:$LIBRARY_PATH"
export C_INCLUDE_PATH="/usr/local/include:/usr/local/opt/openssl@3/include:/usr/local/Cellar/gettext/0.25.1/include:$C_INCLUDE_PATH"
export CPLUS_INCLUDE_PATH="/usr/local/include:/usr/local/opt/openssl@3/include:/usr/local/Cellar/gettext/0.25.1/include:$CPLUS_INCLUDE_PATH"
export PATH="/usr/local/bin:$PATH"

# Ajout des flags FLTK spécifiques
echo "🎯 Configuration des flags FLTK..."
FLTK_CXXFLAGS="$(/usr/local/bin/fltk-config --cxxflags)"
FLTK_LDFLAGS="$(/usr/local/bin/fltk-config --ldflags)"
echo "FLTK_CXXFLAGS: $FLTK_CXXFLAGS"
echo "FLTK_LDFLAGS: $FLTK_LDFLAGS"

# Mise à jour des variables avec les flags FLTK
export CXXFLAGS="$CXXFLAGS $FLTK_CXXFLAGS"
export LDFLAGS="$LDFLAGS $FLTK_LDFLAGS"
export LIBS="-lfltk $LIBS"

# Configuration du build
echo "🔧 Configuration du build..."
# Pour la cross-compilation, forcer la détection de libfltk
export ac_cv_lib_fltk_main=yes
./configure \
    --host=x86_64-apple-darwin \
    --build=arm64-apple-darwin \
    --prefix=/usr/local \
    CFLAGS="$CFLAGS" \
    CXXFLAGS="$CXXFLAGS" \
    OBJCFLAGS="$OBJCFLAGS" \
    OBJCXXFLAGS="$OBJCXXFLAGS" \
    LDFLAGS="$LDFLAGS -L/usr/local/lib -L/usr/local/opt/openssl@3/lib -L/usr/local/Cellar/gettext/0.25.1/lib" \
    CPPFLAGS="-I/usr/local/include -I/usr/local/opt/openssl@3/include -I/usr/local/Cellar/gettext/0.25.1/include" \
    LIBS="$LIBS"


# Compilation
echo "🏗️  Compilation en cours..."
make -j$(sysctl -n hw.ncpu)

# Vérification de l'architecture
echo "🔍 Vérification de l'architecture..."
if [ -f "src/butt" ]; then
    echo "Architecture compilée:"
    file src/butt
    echo ""
    echo "Dépendances:"
    otool -L src/butt | head -10
else
    echo "❌ Erreur: Exécutable non trouvé"
    exit 1
fi

# Création du bundle Intel
echo "📦 Création du bundle Intel..."
create_intel_bundle() {
    local bundle_dir="$BUILD_DIR/$BUNDLE_NAME"
    local contents_dir="$bundle_dir/Contents"
    local macos_dir="$contents_dir/MacOS"
    local frameworks_dir="$contents_dir/Frameworks"
    local resources_dir="$contents_dir/Resources"
    
    # Création de la structure
    mkdir -p "$macos_dir" "$frameworks_dir" "$resources_dir"
    
    # Copie de l'exécutable
    cp "src/butt" "$macos_dir/$APP_NAME"
    chmod +x "$macos_dir/$APP_NAME"
    
    # Copie des librairies StereoTool (utiliser la version 992 stable)
    local stereo_lib_found=false
    for lib_path in "../libStereoTool_992/libStereoTool64.dylib" \
                    "../libStereoTool_1051/lib/macOS/Universal/64/libStereoTool_64.dylib" \
                    "libStereoTool64.dylib"; do
        if [ -f "$lib_path" ]; then
            echo "✅ Copie de la bibliothèque StereoTool: $lib_path"
            cp "$lib_path" "$frameworks_dir/libStereoTool64.dylib"
            stereo_lib_found=true
            break
        fi
    done
    
    if [ "$stereo_lib_found" = false ]; then
        echo "❌ Erreur: Aucune bibliothèque StereoTool trouvée"
        exit 1
    fi
    
    # Copie des ressources
    if [ -f "icons/butt.icns" ]; then
        cp "icons/butt.icns" "$resources_dir/"
    fi
    
    # Copie de la documentation
    for doc in "README" "ChangeLog" "COPYING"; do
        if [ -f "$doc" ]; then
            cp "$doc" "$resources_dir/${doc}.txt"
        fi
    done
    
    # Création du Info.plist
    cat > "$contents_dir/Info.plist" << EOF
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
    <key>CFBundleName</key>
    <string>$APP_NAME Intel</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.12</string>
    <key>LSArchitecturePriority</key>
    <array>
        <string>x86_64</string>
    </array>
    <key>NSMicrophoneUsageDescription</key>
    <string>BUTT nécessite l'accès au microphone pour diffuser de l'audio en direct.</string>
</dict>
</plist>
EOF
    
    # Correction des liens dynamiques
    echo "🔗 Correction des liens dynamiques..."
    
    # Fixer l'ID de la bibliothèque StereoTool
    install_name_tool -id "@executable_path/../Frameworks/libStereoTool64.dylib" \
        "$frameworks_dir/libStereoTool64.dylib"
    
    # Fixer les dépendances de l'exécutable
    otool -L "$macos_dir/$APP_NAME" | grep -E "libStereoTool.*\.dylib" | while read -r dep; do
        dep_path=$(echo "$dep" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]].*//')
        if [[ "$dep_path" =~ libStereoTool ]]; then
            echo "🔄 Correction du lien: $dep_path"
            install_name_tool -change "$dep_path" "@executable_path/../Frameworks/libStereoTool64.dylib" \
                "$macos_dir/$APP_NAME"
        fi
    done
    
    echo "✅ Bundle Intel créé: $bundle_dir"
}

# Créer le bundle
mkdir -p "$BUILD_DIR"
create_intel_bundle

# Vérification finale
echo "🔎 Vérification finale..."
bundle_exe="$BUILD_DIR/$BUNDLE_NAME/Contents/MacOS/$APP_NAME"
if [ -f "$bundle_exe" ]; then
    echo "Architecture du bundle:"
    file "$bundle_exe"
    echo ""
    echo "Dépendances du bundle:"
    otool -L "$bundle_exe" | head -10
else
    echo "❌ Erreur: Bundle non créé"
    exit 1
fi

# Instructions finales
echo ""
echo "🎉 Compilation Intel terminée avec succès!"
echo "==========================================="
echo "Bundle créé: $BUILD_DIR/$BUNDLE_NAME"
echo ""
echo "Pour tester:"
echo "  open $BUILD_DIR/$BUNDLE_NAME"
echo ""
echo "Pour créer un DMG:"
echo "  make -f Makefile.bundle dmg ARCH=x86_64"
echo ""
echo "⚠️  Note: Ce bundle est optimisé pour Intel x86_64 uniquement" 