#!/usr/bin/env bash
set -euo pipefail

# Script de démonstration pour la construction DMG BUTT Enhanced
# Montre le processus complet de construction et test
# Usage: demo_build.sh [--arch arm64|x86_64] [--clean]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_DIR}"

# Configuration
ARCH="${ARCH:-arm64}"
CLEAN_BUILD="${CLEAN_BUILD:-true}"
DEMO_MODE=true

# Couleurs pour output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log() { echo -e "${BLUE}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
demo() { echo -e "${PURPLE}[DEMO]${NC} $*"; }
step() { echo -e "${CYAN}[ÉTAPE]${NC} $*"; }

# Fonction pour afficher l'en-tête
show_header() {
    echo
    echo "🎯 DÉMONSTRATION - Construction DMG BUTT Enhanced"
    echo "=================================================="
    echo
    echo "Architecture cible: ${ARCH}"
    echo "Mode nettoyage: ${CLEAN_BUILD}"
    echo "Répertoire projet: ${PROJECT_DIR}"
    echo
}

# Fonction pour vérifier les prérequis
check_prerequisites() {
    step "Vérification des prérequis..."
    
    local missing_tools=()
    
    # Vérifier les outils requis
    for tool in otool install_name_tool lipo hdiutil; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        error "Outils manquants: ${missing_tools[*]}. Installez Xcode Command Line Tools."
    fi
    
    # Vérifier la présence de StereoTool
    if [[ ! -f "libStereoTool64.dylib" ]]; then
        warn "StereoTool SDK non trouvé dans le répertoire racine"
        warn "Le bundle sera créé sans StereoTool (fonctionnalités limitées)"
    else
        success "StereoTool SDK trouvé"
    fi
    
    # Vérifier la structure du projet
    if [[ ! -f "configure.ac" ]]; then
        error "Fichier configure.ac introuvable. Êtes-vous dans le bon répertoire?"
    fi
    
    success "Prérequis vérifiés"
}

# Fonction pour afficher les informations système
show_system_info() {
    step "Informations système..."
    
    echo "Système: $(sw_vers -productName) $(sw_vers -productVersion)"
    echo "Architecture: $(uname -m)"
    echo "Processeur: $(sysctl -n machdep.cpu.brand_string)"
    echo "Mémoire: $(sysctl -n hw.memsize | awk '{print $1/1024/1024/1024 " GB"}')"
    echo "Cœurs: $(sysctl -n hw.ncpu)"
    echo
}

# Fonction pour nettoyer l'environnement
clean_environment() {
    if [[ "$CLEAN_BUILD" == "true" ]]; then
        step "Nettoyage de l'environnement..."
        
        # Nettoyer les builds précédents
        if [[ -d "build" ]]; then
            log "Suppression du répertoire build..."
            rm -rf build
        fi
        
        # Nettoyer les fichiers de configuration
        if [[ -f "config.h" ]]; then
            log "Suppression de config.h..."
            rm -f config.h
        fi
        
        success "Environnement nettoyé"
    else
        log "Nettoyage désactivé"
    fi
}

# Fonction pour construire le projet
build_project() {
    step "Construction du projet..."
    
    # Configuration
    log "Configuration pour ${ARCH}..."
    ./configure --host="${ARCH}-apple-darwin" \
                CFLAGS="-arch ${ARCH} -mmacosx-version-min=10.12" \
                CXXFLAGS="-arch ${ARCH} -mmacosx-version-min=10.12" \
                LDFLAGS="-arch ${ARCH} -mmacosx-version-min=10.12"
    
    # Compilation
    log "Compilation..."
    make clean
    make -j$(sysctl -n hw.ncpu)
    
    # Vérification
    if [[ -f "src/butt" ]]; then
        local compiled_arch
        compiled_arch=$(lipo -info "src/butt" 2>/dev/null | awk '{print $NF}' || echo "unknown")
        success "Compilation réussie (${compiled_arch})"
    else
        error "Échec de la compilation"
    fi
}

# Fonction pour créer le bundle
create_bundle() {
    step "Création du bundle macOS..."
    
    # Utiliser le script de build
    log "Exécution du script de build..."
    ./scripts/build_universal_dmg.sh --arch "$ARCH" --no-clean
    
    # Vérifier la création
    if [[ -d "build/BUTT.app" ]]; then
        success "Bundle créé: build/BUTT.app"
    else
        error "Échec de la création du bundle"
    fi
}

# Fonction pour tester le bundle
test_bundle() {
    step "Test du bundle..."
    
    # Test automatique
    log "Exécution des tests automatiques..."
    ./scripts/test_bundle.sh build/BUTT.app --verbose
    
    # Test manuel supplémentaire
    log "Test de lancement manuel..."
    if timeout 10s build/BUTT.app/Contents/MacOS/BUTT --version >/dev/null 2>&1; then
        success "Test de lancement réussi"
    else
        warn "Test de lancement échoué ou timeout"
    fi
}

# Fonction pour afficher les informations du bundle
show_bundle_info() {
    step "Informations du bundle..."
    
    local bundle_path="build/BUTT.app"
    local binary_path="$bundle_path/Contents/MacOS/BUTT"
    local frameworks_path="$bundle_path/Contents/Frameworks"
    
    echo "Bundle: $bundle_path"
    echo "Taille: $(du -sh "$bundle_path" | awk '{print $1}')"
    echo
    
    # Architecture
    echo "Architecture:"
    lipo -info "$binary_path" 2>/dev/null || file "$binary_path"
    echo
    
    # Dépendances
    echo "Dépendances non-système:"
    otool -L "$binary_path" 2>/dev/null | grep -v "/System/\|/usr/lib/\|^$binary_path:" | wc -l | awk '{print $1 " librairies"}'
    echo
    
    # Frameworks
    if [[ -d "$frameworks_path" ]]; then
        echo "Frameworks embarqués:"
        ls -1 "$frameworks_path"/*.dylib 2>/dev/null | wc -l | awk '{print $1 " librairies"}'
        echo
    fi
    
    # DMG
    local dmg_files
    dmg_files=$(ls build/*.dmg 2>/dev/null || true)
    if [[ -n "$dmg_files" ]]; then
        echo "DMG créé:"
        for dmg in $dmg_files; do
            echo "  $(basename "$dmg") ($(du -sh "$dmg" | awk '{print $1}'))"
        done
        echo
    fi
}

# Fonction pour afficher les prochaines étapes
show_next_steps() {
    step "Prochaines étapes recommandées..."
    
    echo "1. Test sur machine cible:"
    echo "   - Copier le DMG sur un Mac sans dépendances"
    echo "   - Installer et tester l'application"
    echo
    
    echo "2. Distribution:"
    echo "   - Renommer le DMG avec la version finale"
    echo "   - Créer une documentation d'installation"
    echo "   - Tester sur différentes versions macOS"
    echo
    
    echo "3. Optimisations (optionnel):"
    echo "   - Signature du code pour distribution publique"
    echo "   - Notarisation Apple"
    echo "   - Réduction de la taille du bundle"
    echo
    
    echo "4. Commandes utiles:"
    echo "   # Test du bundle"
    echo "   ./scripts/test_bundle.sh build/BUTT.app"
    echo
    echo "   # Analyse des dépendances"
    echo "   ./scripts/collect_dependencies.sh build/BUTT.app/Contents/MacOS/BUTT build/BUTT.app/Contents/Frameworks --analyze-only"
    echo
    echo "   # Lancement avec debug"
    echo "   BUTT_DEBUG=1 build/BUTT.app/Contents/MacOS/BUTT --version"
    echo
}

# Fonction pour afficher le résumé final
show_summary() {
    echo
    echo "🎉 DÉMONSTRATION TERMINÉE"
    echo "========================="
    echo
    
    local bundle_path="build/BUTT.app"
    local dmg_files
    dmg_files=$(ls build/*.dmg 2>/dev/null || true)
    
    if [[ -d "$bundle_path" ]]; then
        success "Bundle créé avec succès: $bundle_path"
    fi
    
    if [[ -n "$dmg_files" ]]; then
        success "DMG créé avec succès:"
        for dmg in $dmg_files; do
            echo "  - $(basename "$dmg")"
        done
    fi
    
    echo
    echo "Le bundle est prêt pour la distribution!"
    echo "Consultez docs/GUIDE_DISTRIBUTION_DMG.md pour plus d'informations."
    echo
}

# Fonction pour afficher l'aide
show_help() {
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  --arch ARCH     Architecture cible (arm64, x86_64) [défaut: arm64]"
    echo "  --no-clean      Ne pas nettoyer l'environnement"
    echo "  --help          Afficher cette aide"
    echo
    echo "Exemples:"
    echo "  $0                    # Construction ARM64 avec nettoyage"
    echo "  $0 --arch x86_64      # Construction x86_64"
    echo "  $0 --no-clean         # Construction sans nettoyage"
    echo
}

# Fonction principale
main() {
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
            --help)
                show_help
                exit 0
                ;;
            *)
                error "Option inconnue: $1"
                ;;
        esac
    done
    
    # Affichage de l'en-tête
    show_header
    
    # Étapes de la démonstration
    check_prerequisites
    show_system_info
    clean_environment
    build_project
    create_bundle
    test_bundle
    show_bundle_info
    show_next_steps
    show_summary
}

# Gestion des erreurs
trap 'error "Erreur à la ligne $LINENO"' ERR

# Exécution
main "$@"
