#!/bin/bash

# Script de configuration BUTT pour Intel x86_64 sur Mac M2
# Résolution du problème libogg et autres dépendances audio
# 
# Usage: ./configure_intel_x86_64.sh

set -e # Arrêter en cas d'erreur

echo "🔧 Configuration BUTT pour Intel x86_64..."
echo "======================================="
echo ""

# Nettoyage des configurations précédentes
echo "🧹 Nettoyage des configurations précédentes..."
make clean 2>/dev/null || true
rm -f config.cache config.log config.status
rm -f Makefile config.h

echo ""
echo "📍 Configuration de l'environnement x86_64..."

# **1. FORCER L'ARCHITECTURE x86_64**
export ARCH_FLAGS="-arch x86_64"
export MIN_OSX="-mmacosx-version-min=10.12"

# **2. CONFIGURER LES COMPILATEURS**
export CC="clang ${ARCH_FLAGS}"
export CXX="clang++ ${ARCH_FLAGS}"
export OBJC="clang ${ARCH_FLAGS}"
export OBJCXX="clang++ ${ARCH_FLAGS}"

# **3. FLAGS DE COMPILATION**
export CFLAGS="${ARCH_FLAGS} ${MIN_OSX}"
export CXXFLAGS="${ARCH_FLAGS} ${MIN_OSX}"
export OBJCFLAGS="${ARCH_FLAGS} ${MIN_OSX}"
export OBJCXXFLAGS="${ARCH_FLAGS} ${MIN_OSX}"
export LDFLAGS="${ARCH_FLAGS} ${MIN_OSX}"

# **4. PKG_CONFIG - CRUCIAL POUR TROUVER LIBOGG**
export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/local/share/pkgconfig"

# **5. CHEMINS VERS LES BIBLIOTHÈQUES x86_64**
export LIBRARY_PATH="/usr/local/lib:${LIBRARY_PATH:-}"
export C_INCLUDE_PATH="/usr/local/include:${C_INCLUDE_PATH:-}"
export CPLUS_INCLUDE_PATH="/usr/local/include:${CPLUS_INCLUDE_PATH:-}"

# **6. FLAGS POUR LE LINKER** 
export LDFLAGS="${LDFLAGS} -L/usr/local/lib"
export CPPFLAGS="-I/usr/local/include"

# **7. PRIORISER LES OUTILS x86_64**
export PATH="/usr/local/bin:${PATH}"

echo ""
echo "🔍 Vérification des dépendances..."

# Vérification des dépendances critiques
dependencies=("ogg" "vorbis" "vorbisenc" "opus")
missing_deps=()

for dep in "${dependencies[@]}"; do
    if pkg-config --exists "$dep"; then
        version=$(pkg-config --modversion "$dep")
        echo "✅ $dep v$version - $(pkg-config --variable=libdir $dep)"
    else
        echo "❌ $dep - NON TROUVÉ"
        missing_deps+=("$dep")
    fi
done

# Vérification de lame (qui n'a pas de pkg-config)
if [ -f "/usr/local/lib/libmp3lame.dylib" ]; then
    echo "✅ lame - /usr/local/lib/libmp3lame.dylib"
else
    echo "❌ lame - NON TROUVÉ"
    missing_deps+=("lame")
fi

if [ ${#missing_deps[@]} -ne 0 ]; then
    echo ""
    echo "❌ ERREUR: Dépendances manquantes: ${missing_deps[*]}"
    echo ""
    echo "Pour les installer (x86_64):"
    echo "arch -x86_64 /usr/local/bin/brew install libogg libvorbis opus lame"
    exit 1
fi

echo ""
echo "🎯 Configuration du build..."

# **8. FORCER LA DÉTECTION DES BIBLIOTHÈQUES**
# Certaines détections peuvent échouer en cross-compilation
export ac_cv_lib_fltk_main=yes

# **9. CONFIGURATION AVEC TOUS LES PARAMÈTRES**
echo ""
echo "▶️  Lancement de ./configure..."
echo ""

./configure \
    --host=x86_64-apple-darwin \
    --build=$(uname -m)-apple-darwin \
    --prefix=/usr/local \
    CC="$CC" \
    CXX="$CXX" \
    OBJC="$OBJC" \
    OBJCXX="$OBJCXX" \
    CFLAGS="$CFLAGS" \
    CXXFLAGS="$CXXFLAGS" \
    OBJCFLAGS="$OBJCFLAGS" \
    OBJCXXFLAGS="$OBJCXXFLAGS" \
    LDFLAGS="$LDFLAGS" \
    CPPFLAGS="$CPPFLAGS" \
    PKG_CONFIG_PATH="$PKG_CONFIG_PATH"

# **10. VÉRIFICATION DU SUCCÈS**
if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Configuration réussie !"
    echo ""
    echo "📝 Prochaines étapes:"
    echo "   make -j$(sysctl -n hw.ncpu)    # Compilation"
    echo "   make install                   # Installation (optionnel)"
    echo ""
    echo "🔍 Variables d'environnement utilisées:"
    echo "   CC=$CC"
    echo "   PKG_CONFIG_PATH=$PKG_CONFIG_PATH" 
    echo "   LDFLAGS=$LDFLAGS"
    echo "   CPPFLAGS=$CPPFLAGS"
else
    echo ""
    echo "❌ Échec de la configuration !"
    echo ""
    echo "📋 Pour diagnostiquer:"
    echo "   tail -50 config.log    # Voir les erreurs détaillées"
    echo "   ./configure --help     # Voir toutes les options"
    exit 1
fi