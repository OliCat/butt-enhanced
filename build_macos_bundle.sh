#!/bin/bash

# Script de création du bundle macOS pour BUTT avec StereoTool SDK
# Version optimisée pour Mac M1/M2 (ARM64)
# Usage: ./build_macos_bundle.sh

set -e  # Arrêter en cas d'erreur

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

echo_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

echo_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

echo_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Configuration
APP_NAME="BUTT"
VERSION="1.45.0-StereoTool"
BUNDLE_NAME="${APP_NAME}.app"
BUILD_DIR="build"
BUNDLE_DIR="${BUILD_DIR}/${BUNDLE_NAME}"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
FRAMEWORKS_DIR="${CONTENTS_DIR}/Frameworks"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
LOCALE_DIR="${RESOURCES_DIR}/locale"

# Chemins sources
SRC_EXECUTABLE="src/butt"
STEREO_TOOL_LIB="libStereoTool64.dylib"
ICON_FILE="icons/butt.icns"

echo ""
echo "=========================================="
echo "  Création du Bundle macOS - BUTT"
echo "  Version: ${VERSION}"
echo "  Architecture: ARM64 (Apple Silicon)"
echo "=========================================="
echo ""

# Vérification de l'exécutable
if [ ! -f "${SRC_EXECUTABLE}" ]; then
    echo_error "L'exécutable ${SRC_EXECUTABLE} n'existe pas!"
    echo_info "Compilation en cours..."
    make clean && make -j4
    if [ ! -f "${SRC_EXECUTABLE}" ]; then
        echo_error "Échec de la compilation"
        exit 1
    fi
fi

echo_info "Vérification de l'architecture de l'exécutable..."
if file "${SRC_EXECUTABLE}" | grep -q "arm64"; then
    echo_success "Exécutable ARM64 détecté"
else
    echo_warning "L'exécutable n'est pas ARM64 natif"
fi

# Nettoyage et création de la structure
echo_info "Création de la structure du bundle..."
rm -rf "${BUNDLE_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${FRAMEWORKS_DIR}"
mkdir -p "${RESOURCES_DIR}"
mkdir -p "${LOCALE_DIR}"

# Copie de l'exécutable
echo_info "Copie de l'exécutable..."
cp "${SRC_EXECUTABLE}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

# Fonction pour copier une bibliothèque et corriger ses chemins
copy_and_fix_dylib() {
    local lib_path="$1"
    local lib_name=$(basename "$lib_path")
    
    if [ ! -f "$lib_path" ]; then
        echo_warning "Bibliothèque non trouvée: $lib_path"
        return 1
    fi
    
    # Copier si pas déjà présent
    if [ ! -f "${FRAMEWORKS_DIR}/${lib_name}" ]; then
        cp "$lib_path" "${FRAMEWORKS_DIR}/"
        chmod +w "${FRAMEWORKS_DIR}/${lib_name}"
        echo "  ✓ $lib_name"
    fi
    
    return 0
}

# Fonction récursive pour copier toutes les dépendances
copy_dependencies() {
    local binary="$1"
    local processed_libs="${2:-}"
    
    # Obtenir les dépendances
    local deps=$(otool -L "$binary" 2>/dev/null | grep -E "\.dylib|\.framework" | awk '{print $1}' | grep -v "^/System" | grep -v "^/usr/lib" | grep -v "@rpath" | grep -v "@executable_path" | grep -v "@loader_path")
    
    for dep in $deps; do
        local lib_name=$(basename "$dep")
        
        # Éviter les doublons
        if echo "$processed_libs" | grep -q "$lib_name"; then
            continue
        fi
        
        # Si c'est un chemin absolu vers Homebrew
        if [[ "$dep" == /opt/homebrew/* ]] || [[ "$dep" == /usr/local/* ]]; then
            if copy_and_fix_dylib "$dep"; then
                processed_libs="$processed_libs $lib_name"
                # Récursion pour les dépendances de cette lib
                copy_dependencies "${FRAMEWORKS_DIR}/${lib_name}" "$processed_libs"
            fi
        fi
    done
}

# Copie des bibliothèques système Homebrew
echo_info "Copie des bibliothèques Homebrew..."
copy_dependencies "${MACOS_DIR}/${APP_NAME}"

# Copie de StereoTool
echo_info "Copie de StereoTool SDK..."
if [ -f "${STEREO_TOOL_LIB}" ]; then
    cp "${STEREO_TOOL_LIB}" "${FRAMEWORKS_DIR}/"
    chmod +w "${FRAMEWORKS_DIR}/${STEREO_TOOL_LIB}"
    echo_success "StereoTool SDK copié"
else
    echo_error "StereoTool SDK non trouvé: ${STEREO_TOOL_LIB}"
    exit 1
fi

# Fonction pour changer les chemins des bibliothèques
fix_library_paths() {
    local binary="$1"
    local is_framework="${2:-no}"
    
    echo_info "Correction des chemins pour $(basename $binary)..."
    
    # Changer l'ID de la bibliothèque si c'est un framework
    if [ "$is_framework" = "yes" ]; then
        install_name_tool -id "@rpath/$(basename $binary)" "$binary" 2>/dev/null || true
        
        # Ajouter rpath aux bibliothèques pour qu'elles puissent se trouver mutuellement
        install_name_tool -add_rpath "@loader_path" "$binary" 2>/dev/null || true
        install_name_tool -add_rpath "@loader_path/." "$binary" 2>/dev/null || true
    fi
    
    # Obtenir toutes les dépendances
    local deps=$(otool -L "$binary" 2>/dev/null | grep -E "\.dylib" | awk '{print $1}')
    
    for dep in $deps; do
        local lib_name=$(basename "$dep")
        
        # Ignorer les bibliothèques système
        if [[ "$dep" == /System/* ]] || [[ "$dep" == /usr/lib/* ]]; then
            continue
        fi
        
        # Ignorer si c'est déjà relatif
        if [[ "$dep" == @rpath/* ]] || [[ "$dep" == @executable_path/* ]] || [[ "$dep" == @loader_path/* ]]; then
            continue
        fi
        
        # Vérifier si la lib existe dans Frameworks
        if [ -f "${FRAMEWORKS_DIR}/${lib_name}" ]; then
            if [ "$is_framework" = "yes" ]; then
                # Pour les frameworks, utiliser @loader_path
                install_name_tool -change "$dep" "@loader_path/${lib_name}" "$binary" 2>/dev/null || true
            else
                # Pour l'exécutable principal, utiliser @executable_path
                install_name_tool -change "$dep" "@executable_path/../Frameworks/${lib_name}" "$binary" 2>/dev/null || true
            fi
        fi
    done
}

# Ajouter rpath à l'exécutable et supprimer les rpaths vers Homebrew
echo_info "Configuration des chemins de recherche..."
# Supprimer les rpaths Homebrew qui ne seront pas présents
install_name_tool -delete_rpath "/usr/local/lib" "${MACOS_DIR}/${APP_NAME}" 2>/dev/null || true
install_name_tool -delete_rpath "/opt/homebrew/lib" "${MACOS_DIR}/${APP_NAME}" 2>/dev/null || true
# Ajouter le rpath vers Frameworks
install_name_tool -add_rpath "@executable_path/../Frameworks" "${MACOS_DIR}/${APP_NAME}" 2>/dev/null || true
install_name_tool -add_rpath "@loader_path/../Frameworks" "${MACOS_DIR}/${APP_NAME}" 2>/dev/null || true

# Correction des chemins de l'exécutable principal
fix_library_paths "${MACOS_DIR}/${APP_NAME}" "no"

# Correction des chemins pour toutes les bibliothèques
echo_info "Correction des chemins des frameworks..."
for dylib in "${FRAMEWORKS_DIR}"/*.dylib; do
    if [ -f "$dylib" ]; then
        fix_library_paths "$dylib" "yes"
    fi
done

# Supprimer les signatures invalidées et re-signer ad-hoc
echo_info "Re-signature du bundle..."
# Supprimer les anciennes signatures
codesign --remove-signature "${MACOS_DIR}/${APP_NAME}" 2>/dev/null || true
for dylib in "${FRAMEWORKS_DIR}"/*.dylib; do
    if [ -f "$dylib" ]; then
        codesign --remove-signature "$dylib" 2>/dev/null || true
    fi
done

# Re-signer ad-hoc (signature locale, pas pour distribution)
codesign -s - --force --deep "${BUNDLE_DIR}" 2>/dev/null || true
echo_success "Bundle re-signé"

# Copie de l'icône
echo_info "Copie des ressources..."
if [ -f "${ICON_FILE}" ]; then
    cp "${ICON_FILE}" "${RESOURCES_DIR}/"
    echo_success "Icône copiée"
else
    echo_warning "Icône non trouvée: ${ICON_FILE}"
fi

# Copie des fichiers de localisation
echo_info "Copie des fichiers de localisation..."
if [ -d "po" ]; then
    for lang_dir in po/*/; do
        if [ -d "$lang_dir" ]; then
            lang=$(basename "$lang_dir")
            mkdir -p "${LOCALE_DIR}/${lang}/LC_MESSAGES"
            if [ -f "po/${lang}/butt.mo" ]; then
                cp "po/${lang}/butt.mo" "${LOCALE_DIR}/${lang}/LC_MESSAGES/"
            fi
        fi
    done
    echo_success "Localisations copiées"
fi

# Copie des fichiers de documentation
echo_info "Copie de la documentation..."
for doc in README COPYING ChangeLog AUTHORS; do
    if [ -f "$doc" ]; then
        cp "$doc" "${RESOURCES_DIR}/${doc}.txt"
    fi
done

# Copie du fichier de notice de distribution
cat > "${RESOURCES_DIR}/DISTRIBUTION_NOTICE.txt" << 'EOF'
BUTT - broadcast using this tool
Version avec StereoTool SDK intégré

Ce bundle inclut :
- BUTT (broadcast using this tool) - GPL v2
- StereoTool SDK - Licence Professionnelle
- Support AES67 pour streaming audio professionnel
- Bibliothèques Homebrew (diverses licences open source)

Pour plus d'informations :
- BUTT: https://danielnoethen.de/butt/
- StereoTool: https://www.stereotool.com/

Date de création: $(date +"%Y-%m-%d")
Architecture: ARM64 (Apple Silicon)
EOF

# Création du fichier Info.plist
echo_info "Création du fichier Info.plist..."
cat > "${CONTENTS_DIR}/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>butt.icns</string>
    <key>CFBundleIdentifier</key>
    <string>de.danielnoethen.butt.stereotool</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>BUTT (StereoTool Edition)</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>BUTT nécessite l'accès au microphone pour diffuser de l'audio en direct.</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.music</string>
    <key>LSArchitecturePriority</key>
    <array>
        <string>arm64</string>
    </array>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>MacOSX</string>
    </array>
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
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
EOF

echo_success "Info.plist créé"

# Vérification du bundle
echo ""
echo_info "Vérification du bundle..."
echo ""

# Vérifier l'exécutable
if [ -f "${MACOS_DIR}/${APP_NAME}" ]; then
    echo "  ✓ Exécutable: ${APP_NAME}"
    file "${MACOS_DIR}/${APP_NAME}" | sed 's/^/    /'
else
    echo_error "Exécutable manquant!"
fi

# Vérifier les frameworks
echo ""
echo "  📚 Frameworks copiés:"
ls -1 "${FRAMEWORKS_DIR}" | sed 's/^/    /'

# Vérifier les dépendances
echo ""
echo "  🔗 Dépendances de l'exécutable:"
otool -L "${MACOS_DIR}/${APP_NAME}" | grep -E "\.dylib" | head -10 | sed 's/^/    /'

# Vérifier StereoTool
echo ""
if [ -f "${FRAMEWORKS_DIR}/${STEREO_TOOL_LIB}" ]; then
    echo "  ✓ StereoTool SDK présent"
    otool -L "${FRAMEWORKS_DIR}/${STEREO_TOOL_LIB}" | grep -E "\.dylib" | head -5 | sed 's/^/    /'
else
    echo_error "StereoTool SDK manquant!"
fi

# Taille du bundle
echo ""
BUNDLE_SIZE=$(du -sh "${BUNDLE_DIR}" | awk '{print $1}')
echo "  📦 Taille du bundle: ${BUNDLE_SIZE}"

# Test de lancement rapide
echo ""
echo_info "Test de lancement rapide..."
if "${MACOS_DIR}/${APP_NAME}" --help > /dev/null 2>&1; then
    echo_success "L'exécutable peut démarrer"
else
    echo_warning "Le test de lancement a échoué (peut être normal sans display)"
fi

# Résumé final
echo ""
echo "=========================================="
echo_success "Bundle créé avec succès!"
echo "=========================================="
echo ""
echo "📍 Emplacement: ${BUNDLE_DIR}"
echo "📦 Taille: ${BUNDLE_SIZE}"
echo "🏗  Architecture: ARM64 (Apple Silicon)"
echo ""
echo "Prochaines étapes:"
echo "  1. Test: open ${BUNDLE_DIR}"
echo "  2. DMG:  make -f Makefile.bundle dmg"
echo "  3. Installer: sudo cp -R ${BUNDLE_DIR} /Applications/"
echo ""

