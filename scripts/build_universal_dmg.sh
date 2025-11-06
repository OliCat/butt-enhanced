#!/usr/bin/env bash
set -euo pipefail

# Script de construction DMG universel pour BUTT Enhanced avec StereoTool
# Crée un bundle macOS ARM64 avec toutes les dépendances embarquées
# Auteur: Script automatisé pour distribution privée
# Version: 1.0

# Configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_DIR}"

APP_NAME="BUTT"
BUNDLE_NAME="${APP_NAME}.app"
VERSION="1.45.0"
BUNDLE_ID="de.danielnoethen.butt"

# Répertoires
BUILD_DIR="${PROJECT_DIR}/build"
BUNDLE_DIR="${BUILD_DIR}/${BUNDLE_NAME}"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
FRAMEWORKS_DIR="${CONTENTS_DIR}/Frameworks"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

# Options
ARCH="${ARCH:-arm64}"  # Par défaut ARM64 pour distribution privée
CLEAN_BUILD="${CLEAN_BUILD:-true}"
CREATE_DMG="${CREATE_DMG:-true}"
SIGN_CODE="${SIGN_CODE:-false}"  # Pas de signature pour distribution privée

# Couleurs pour output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() { echo -e "${BLUE}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }

# Fonction pour détecter l'architecture du binaire
detect_arch() {
    local binary="$1"
    if [[ ! -f "$binary" ]]; then
        error "Binaire introuvable: $binary"
    fi
    
    local file_out
    file_out=$(file "$binary" 2>/dev/null || echo "unknown")
    
    if echo "$file_out" | grep -q "x86_64"; then
        echo "x86_64"
    elif echo "$file_out" | grep -qi "arm64"; then
        echo "arm64"
    else
        echo "unknown"
    fi
}

# Fonction pour trouver la bibliothèque StereoTool
find_stereotool_lib() {
    local candidates=(
        "../libStereoTool_992/libStereoTool64.dylib"
        "../libStereoTool_1051/lib/macOS/Universal/64/libStereoTool_64.dylib"
        "libStereoTool64.dylib"
        "${PROJECT_DIR}/libStereoTool64.dylib"
    )
    
    for lib_path in "${candidates[@]}"; do
        if [[ -f "$lib_path" ]]; then
            echo "$lib_path"
            return 0
        fi
    done
    
    # Recherche globale (fallback)
    local found
    found=$(find "${PROJECT_DIR}" -type f -name "libStereoTool*64*.dylib" -maxdepth 4 2>/dev/null | head -1 || true)
    if [[ -n "$found" ]]; then
        echo "$found"
        return 0
    fi
    
    return 1
}

# Fonction pour collecter les dépendances
collect_dependencies() {
    local binary="$1"
    local frameworks_dir="$2"
    
    log "Collecte des dépendances pour $(basename "$binary")..."
    
    # Créer le répertoire Frameworks s'il n'existe pas
    mkdir -p "$frameworks_dir"
    
    # Fonction récursive pour collecter les dépendances (sans suivi d'état strict)
    collect_deps_recursive() {
        local target="$1"
        otool -L "$target" 2>/dev/null | grep -v "^$target:" | awk '{print $1}' | while read -r dep; do
            # Ignorer les libs système et chemins déjà relatifs au bundle
            [[ "$dep" =~ ^/System/ ]] && continue
            [[ "$dep" =~ ^/usr/lib/ ]] && continue
            [[ "$dep" =~ ^@(executable_path|loader_path|rpath) ]] && continue

            local dep_name
            dep_name=$(basename "$dep")
            local dest_path="$frameworks_dir/$dep_name"

            if [[ ! -f "$dest_path" ]]; then
                log "  Copie: $dep_name"
                cp "$dep" "$dest_path"
                install_name_tool -id "@executable_path/../Frameworks/$dep_name" "$dest_path" 2>/dev/null || true
                # Descendre récursivement
                collect_deps_recursive "$dest_path"
            fi
        done
    }

    collect_deps_recursive "$binary"
}

# Fonction pour corriger les chemins de dépendances
fix_dependencies() {
    local binary="$1"
    local frameworks_dir="$2"
    
    log "Correction des chemins de dépendances pour $(basename "$binary")..."
    
    otool -L "$binary" 2>/dev/null | grep -v "^$binary:" | awk '{print $1}' | while read -r dep; do
        # Skip system libs
        [[ "$dep" =~ ^/System/ ]] && continue
        [[ "$dep" =~ ^/usr/lib/ ]] && continue
        [[ "$dep" =~ ^@(executable_path|loader_path|rpath) ]] && continue
        
        local dep_name=$(basename "$dep")
        local new_path="@executable_path/../Frameworks/$dep_name"
        
        log "  Correction: $dep -> $new_path"
        install_name_tool -change "$dep" "$new_path" "$binary" 2>/dev/null || true
    done
}

# Fonction pour créer la structure du bundle
create_bundle_structure() {
    log "Création de la structure du bundle..."
    
    if [[ "$CLEAN_BUILD" == "true" ]]; then
        rm -rf "$BUILD_DIR"
    fi
    
    mkdir -p "$MACOS_DIR" "$FRAMEWORKS_DIR" "$RESOURCES_DIR"
}

# Fonction pour créer le fichier Info.plist
create_info_plist() {
    log "Création du fichier Info.plist..."
    
    cat > "${CONTENTS_DIR}/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>butt.icns</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
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
    <key>LSArchitecturePriority</key>
    <array>
        <string>${ARCH}</string>
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
</dict>
</plist>
EOF
}

# Fonction pour copier les ressources
copy_resources() {
    log "Copie des ressources..."
    
    # Icône
    if [[ -f "icons/butt.icns" ]]; then
        cp "icons/butt.icns" "${RESOURCES_DIR}/"
    else
        warn "Icône introuvable: icons/butt.icns"
    fi
    
    # Documentation
    [[ -f "README" ]] && cp "README" "${RESOURCES_DIR}/README.txt"
    [[ -f "ChangeLog" ]] && cp "ChangeLog" "${RESOURCES_DIR}/ChangeLog.txt"
    [[ -f "COPYING" ]] && cp "COPYING" "${RESOURCES_DIR}/LICENSE.txt"
    
    # Notice de distribution privée
    cat > "${RESOURCES_DIR}/DISTRIBUTION_NOTICE.txt" <<EOF
BUTT Enhanced - Distribution Privée
====================================

Ce bundle contient:
- BUTT Enhanced v${VERSION}
- StereoTool SDK (licence Pro)
- Toutes les dépendances embarquées

Architecture: ${ARCH}
Compatibilité: macOS 10.12+

Usage:
- Glisser BUTT.app dans le dossier Applications
- Lancer l'application
- StereoTool SDK sera automatiquement chargé

Note: Distribution privée uniquement.
Ne pas redistribuer sans autorisation.

Dernière mise à jour: $(date)
EOF
}

# Fonction pour compiler le projet
build_project() {
    log "Vérification du binaire pour ${ARCH}..."
    
    # Vérifier si le binaire existe déjà
    if [[ -f "src/butt" ]]; then
        local existing_arch
        existing_arch=$(detect_arch "src/butt")
        log "Binaire existant trouvé: ${existing_arch}"
        
        # Exiger l'architecture cible exacte
        if [[ "$existing_arch" == "$ARCH" ]]; then
            log "Binaire ${ARCH} correspond à l'architecture cible, réutilisation..."
            return 0
        else
            error "Binaire existant (${existing_arch}) ne correspond pas à l'architecture cible (${ARCH}). Veuillez recompiler pour ${ARCH}.\nExemple: CFLAGS='-arch ${ARCH} -mmacosx-version-min=11.0' CXXFLAGS='-arch ${ARCH} -mmacosx-version-min=11.0' LDFLAGS='-arch ${ARCH} -mmacosx-version-min=11.0' ./configure --host=${ARCH}-apple-darwin && make clean && make"
        fi
    else
        error "Aucun binaire trouvé. Veuillez compiler le projet d'abord avec 'make'"
    fi
}

# Fonction pour créer le bundle
create_bundle() {
    log "Création du bundle macOS..."
    
    # Copier l'exécutable
    cp "src/butt" "${MACOS_DIR}/${APP_NAME}"
    chmod +x "${MACOS_DIR}/${APP_NAME}"
    
    # Trouver et copier StereoTool
    local st_lib
    if st_lib=$(find_stereotool_lib); then
        log "Bibliothèque StereoTool trouvée: $(basename "$st_lib")"
        cp "$st_lib" "${FRAMEWORKS_DIR}/libStereoTool64.dylib"
    else
        warn "Aucune bibliothèque StereoTool trouvée. Le bundle peut manquer des fonctionnalités."
    fi
    
    # Collecter les dépendances générales (hors chemins @)
    collect_dependencies "${MACOS_DIR}/${APP_NAME}" "$FRAMEWORKS_DIR"

    # Embarquer explicitement FLTK depuis Homebrew ARM64
    FLTK_PREFIX=$(brew --prefix fltk 2>/dev/null || echo "/opt/homebrew/opt/fltk")
    FLTK_LIB_DIR="${FLTK_PREFIX}/lib"
    if [[ -d "${FLTK_LIB_DIR}" ]]; then
        for fl in libfltk.1.4.dylib libfltk_images.1.4.dylib; do
            if [[ -f "${FLTK_LIB_DIR}/${fl}" ]]; then
                # Si la lib existe déjà, supprimer puis recopier pour éviter les permissions en lecture seule
                if [[ -f "${FRAMEWORKS_DIR}/${fl}" ]]; then
                    rm -f "${FRAMEWORKS_DIR}/${fl}" 2>/dev/null || true
                fi
                log "  Copie FLTK: ${fl}"
                cp "${FLTK_LIB_DIR}/${fl}" "${FRAMEWORKS_DIR}/${fl}"
                chmod u+w "${FRAMEWORKS_DIR}/${fl}" 2>/dev/null || true
                install_name_tool -id "@executable_path/../Frameworks/${fl}" "${FRAMEWORKS_DIR}/${fl}" 2>/dev/null || true
                # S'assurer que l'exécutable pointe vers Frameworks
                install_name_tool -change "${FLTK_LIB_DIR}/${fl}" "@executable_path/../Frameworks/${fl}" "${MACOS_DIR}/${APP_NAME}" 2>/dev/null || true
                install_name_tool -change "/usr/local/lib/${fl}" "@executable_path/../Frameworks/${fl}" "${MACOS_DIR}/${APP_NAME}" 2>/dev/null || true
            else
                warn "Lib FLTK manquante: ${FLTK_LIB_DIR}/${fl}"
            fi
        done
    else
        warn "Répertoire FLTK introuvable: ${FLTK_LIB_DIR}. Assurez-vous que FLTK ARM64 est installé via Homebrew."
    fi

    # Corriger les chemins de dépendances
    fix_dependencies "${MACOS_DIR}/${APP_NAME}" "$FRAMEWORKS_DIR"
    
    # Corriger les dépendances des librairies dans Frameworks
    for lib in "${FRAMEWORKS_DIR}"/*.dylib; do
        if [[ -f "$lib" ]]; then
            fix_dependencies "$lib" "$FRAMEWORKS_DIR"
        fi
    done
    
    success "Bundle créé: ${BUNDLE_DIR}"
}

# Fonction pour créer le DMG
create_dmg() {
    if [[ "$CREATE_DMG" != "true" ]]; then
        return 0
    fi
    
    log "Création du DMG..."
    
    local dmg_name="BUTT-${VERSION}-${ARCH}-macOS-StereoTool"
    local dmg_path="${BUILD_DIR}/${dmg_name}.dmg"
    
    # Supprimer le DMG existant
    rm -f "$dmg_path"
    
    # Créer le DMG
    hdiutil create -srcfolder "$BUNDLE_DIR" \
                   -volname "$dmg_name" \
                   -format UDZO \
                   -imagekey zlib-level=9 \
                   "$dmg_path"
    
    success "DMG créé: $dmg_path"
}

# Fonction pour signer le code (optionnel)
sign_code() {
    if [[ "$SIGN_CODE" != "true" ]]; then
        log "Signature code désactivée (distribution privée)"
        return 0
    fi
    
    log "Signature du code..."
    
    # Vérifier la présence du certificat
    if ! security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
        warn "Certificat 'Developer ID Application' non trouvé. Signature ignorée."
        return 0
    fi
    
    # Signer le bundle
    codesign --force --deep --sign "Developer ID Application" "$BUNDLE_DIR"
    
    # Vérifier la signature
    codesign -dvvv "$BUNDLE_DIR"
    
    success "Bundle signé"
}

# Fonction pour afficher les informations finales
show_summary() {
    echo
    success "=== RÉSUMÉ DE LA CONSTRUCTION ==="
    echo
    echo "Bundle créé: ${BUNDLE_DIR}"
    echo "Architecture: ${ARCH}"
    echo "Version: ${VERSION}"
    echo
    
    if [[ "$CREATE_DMG" == "true" ]]; then
        local dmg_name="BUTT-${VERSION}-${ARCH}-macOS-StereoTool.dmg"
        echo "DMG créé: ${BUILD_DIR}/${dmg_name}"
        echo
    fi
    
    echo "Tests recommandés:"
    echo "1. Vérifier l'architecture: lipo -info ${MACOS_DIR}/${APP_NAME}"
    echo "2. Vérifier les dépendances: otool -L ${MACOS_DIR}/${APP_NAME}"
    echo "3. Tester le lancement: open ${BUNDLE_DIR}"
    echo "4. Vérifier StereoTool: BUTT_DEBUG=1 ${MACOS_DIR}/${APP_NAME} --version"
    echo
    echo "Pour installer: Glisser BUTT.app dans le dossier Applications"
    echo
}

# Fonction principale
main() {
    echo "🎯 Construction DMG BUTT Enhanced avec StereoTool"
    echo "Architecture: ${ARCH}"
    echo "Version: ${VERSION}"
    echo "Distribution: Privée"
    echo
    
    # Vérifications préliminaires
    if ! command -v otool >/dev/null 2>&1; then
        error "otool non trouvé. Installez Xcode Command Line Tools."
    fi
    
    if ! command -v install_name_tool >/dev/null 2>&1; then
        error "install_name_tool non trouvé. Installez Xcode Command Line Tools."
    fi
    
    # Étapes de construction
    create_bundle_structure
    create_info_plist
    copy_resources
    build_project
    create_bundle
    sign_code
    create_dmg
    show_summary
}

# Gestion des arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --arch)
            ARCH="$2"
            shift 2
            ;;
        --no-clean)
            CLEAN_BUILD="false"
            shift
            ;;
        --no-dmg)
            CREATE_DMG="false"
            shift
            ;;
        --sign)
            SIGN_CODE="true"
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --arch ARCH     Architecture cible (arm64, x86_64) [défaut: arm64]"
            echo "  --no-clean      Ne pas nettoyer le build précédent"
            echo "  --no-dmg        Ne pas créer de DMG"
            echo "  --sign          Signer le code (nécessite certificat Developer ID)"
            echo "  --help          Afficher cette aide"
            exit 0
            ;;
        *)
            error "Option inconnue: $1"
            ;;
    esac
done

# Exécution
main
