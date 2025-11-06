#!/usr/bin/env bash
set -euo pipefail

# Script de test automatique pour bundle macOS BUTT Enhanced
# Vérifie l'architecture, les dépendances, la signature et le fonctionnement
# Usage: test_bundle.sh <bundle_path> [--verbose]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Couleurs pour output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() { echo -e "${BLUE}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
fail() { echo -e "${RED}[FAIL]${NC} $*"; }

# Variables globales
VERBOSE=false
BUNDLE_PATH=""
BINARY_PATH=""
FRAMEWORKS_PATH=""
RESOURCES_PATH=""
TEST_RESULTS=()

# Fonction pour ajouter un résultat de test
add_test_result() {
    local test_name="$1"
    local status="$2"
    local message="$3"
    
    TEST_RESULTS+=("$test_name|$status|$message")
    
    if [[ "$status" == "PASS" ]]; then
        success "$test_name: $message"
    elif [[ "$status" == "WARN" ]]; then
        warn "$test_name: $message"
    else
        fail "$test_name: $message"
    fi
}

# Fonction pour vérifier l'architecture
test_architecture() {
    log "Test de l'architecture..."
    
    if [[ ! -f "$BINARY_PATH" ]]; then
        add_test_result "Architecture" "FAIL" "Binaire introuvable: $BINARY_PATH"
        return 1
    fi
    
    local arch_info
    arch_info=$(lipo -info "$BINARY_PATH" 2>/dev/null || file "$BINARY_PATH")
    
    if echo "$arch_info" | grep -q "arm64"; then
        add_test_result "Architecture" "PASS" "ARM64 détecté"
    elif echo "$arch_info" | grep -q "x86_64"; then
        add_test_result "Architecture" "PASS" "x86_64 détecté"
    else
        add_test_result "Architecture" "WARN" "Architecture non reconnue: $arch_info"
    fi
    
    if [[ "$VERBOSE" == "true" ]]; then
        echo "  Détails: $arch_info"
    fi
}

# Fonction pour vérifier les dépendances
test_dependencies() {
    log "Test des dépendances..."
    
    local unresolved_deps
    unresolved_deps=$(otool -L "$BINARY_PATH" 2>/dev/null | grep -v "@executable_path\|@loader_path\|@rpath\|/System/\|/usr/lib/\|^$BINARY_PATH:" || true)
    
    if [[ -z "$unresolved_deps" ]]; then
        add_test_result "Dépendances" "PASS" "Toutes les dépendances sont résolues"
    else
        add_test_result "Dépendances" "FAIL" "Dépendances non-résolues détectées"
        if [[ "$VERBOSE" == "true" ]]; then
            echo "  Dépendances non-résolues:"
            echo "$unresolved_deps" | sed 's/^/    /'
        fi
    fi
    
    # Vérifier la présence de StereoTool
    if [[ -f "$FRAMEWORKS_PATH/libStereoTool64.dylib" ]]; then
        add_test_result "StereoTool" "PASS" "Bibliothèque StereoTool présente"
    else
        add_test_result "StereoTool" "WARN" "Bibliothèque StereoTool manquante"
    fi
    
    # Compter les librairies dans Frameworks
    local lib_count
    lib_count=$(ls -1 "$FRAMEWORKS_PATH"/*.dylib 2>/dev/null | wc -l)
    add_test_result "Frameworks" "PASS" "$lib_count librairies embarquées"
}

# Fonction pour vérifier la signature
test_code_signing() {
    log "Test de la signature code..."
    
    local sign_info
    sign_info=$(codesign -dvvv "$BUNDLE_PATH" 2>&1 || true)
    
    if echo "$sign_info" | grep -q "Authority="; then
        local authority
        authority=$(echo "$sign_info" | grep "Authority=" | head -1 | sed 's/.*Authority=//')
        add_test_result "Signature" "PASS" "Signé par: $authority"
    else
        add_test_result "Signature" "WARN" "Non signé (normal pour distribution privée)"
    fi
    
    if [[ "$VERBOSE" == "true" ]]; then
        echo "  Détails de la signature:"
        echo "$sign_info" | sed 's/^/    /'
    fi
}

# Fonction pour vérifier les ressources
test_resources() {
    log "Test des ressources..."
    
    local missing_resources=()
    
    # Vérifier l'icône
    if [[ -f "$RESOURCES_PATH/butt.icns" ]]; then
        add_test_result "Icône" "PASS" "Icône présente"
    else
        missing_resources+=("butt.icns")
    fi
    
    # Vérifier la documentation
    if [[ -f "$RESOURCES_PATH/README.txt" ]]; then
        add_test_result "README" "PASS" "README présent"
    else
        missing_resources+=("README.txt")
    fi
    
    if [[ -f "$RESOURCES_PATH/LICENSE.txt" ]]; then
        add_test_result "LICENSE" "PASS" "LICENSE présent"
    else
        missing_resources+=("LICENSE.txt")
    fi
    
    if [[ -f "$RESOURCES_PATH/DISTRIBUTION_NOTICE.txt" ]]; then
        add_test_result "Distribution Notice" "PASS" "Notice de distribution présente"
    else
        missing_resources+=("DISTRIBUTION_NOTICE.txt")
    fi
    
    if [[ ${#missing_resources[@]} -gt 0 ]]; then
        add_test_result "Ressources manquantes" "WARN" "Ressources manquantes: ${missing_resources[*]}"
    fi
}

# Fonction pour tester le lancement
test_launch() {
    log "Test de lancement..."
    
    # Vérifier que le binaire est exécutable
    if [[ ! -x "$BINARY_PATH" ]]; then
        add_test_result "Exécutable" "FAIL" "Binaire non exécutable"
        return 1
    fi
    
    add_test_result "Exécutable" "PASS" "Binaire exécutable"
    
    # Test de lancement avec timeout
    log "Test de lancement avec timeout (10 secondes)..."
    
    local launch_pid
    local launch_output
    local launch_error
    
    # Lancer en arrière-plan avec timeout (macOS compatible)
    "$BINARY_PATH" -v >/tmp/butt_test_output.log 2>/tmp/butt_test_error.log &
    launch_pid=$!
    
    # Attendre la fin du processus avec timeout manuel
    local count=0
    while kill -0 $launch_pid 2>/dev/null && [ $count -lt 10 ]; do
        sleep 1
        count=$((count + 1))
    done
    
    # Tuer le processus s'il est encore en vie
    if kill -0 $launch_pid 2>/dev/null; then
        kill $launch_pid 2>/dev/null || true
        wait $launch_pid 2>/dev/null || true
    fi
    
    # Vérifier les logs
    if [[ -f /tmp/butt_test_output.log ]]; then
        launch_output=$(cat /tmp/butt_test_output.log)
    fi
    
    if [[ -f /tmp/butt_test_error.log ]]; then
        launch_error=$(cat /tmp/butt_test_error.log)
    fi
    
    # Analyser les résultats
    if echo "$launch_output" | grep -q "BUTT"; then
        add_test_result "Lancement" "PASS" "Application lancée avec succès"
    elif echo "$launch_error" | grep -q "StereoTool"; then
        add_test_result "Lancement" "WARN" "Lancement réussi mais StereoTool non chargé"
    else
        add_test_result "Lancement" "FAIL" "Échec du lancement"
        if [[ "$VERBOSE" == "true" ]]; then
            echo "  Output: $launch_output"
            echo "  Error: $launch_error"
        fi
    fi
    
    # Nettoyer les fichiers temporaires
    rm -f /tmp/butt_test_output.log /tmp/butt_test_error.log
}

# Fonction pour tester StereoTool
test_stereotool() {
    log "Test de StereoTool..."
    
    # Test avec variable d'environnement de debug
    local st_output
    st_output=$(BUTT_DEBUG=1 "$BINARY_PATH" -v 2>&1 || true)
    
    if echo "$st_output" | grep -q "StereoTool.*Loaded"; then
        add_test_result "StereoTool Load" "PASS" "StereoTool chargé avec succès"
    elif echo "$st_output" | grep -q "StereoTool.*Could not load"; then
        add_test_result "StereoTool Load" "FAIL" "Échec du chargement de StereoTool"
    else
        add_test_result "StereoTool Load" "WARN" "Statut StereoTool indéterminé"
    fi
    
    if echo "$st_output" | grep -q "StereoTool.*Software version"; then
        local version
        version=$(echo "$st_output" | grep "StereoTool.*Software version" | head -1)
        add_test_result "StereoTool Version" "PASS" "Version détectée: $version"
    else
        add_test_result "StereoTool Version" "WARN" "Version StereoTool non détectée"
    fi
    
    if [[ "$VERBOSE" == "true" ]]; then
        echo "  Output StereoTool:"
        echo "$st_output" | grep -i stereotool | sed 's/^/    /'
    fi
}

# Fonction pour tester les permissions
test_permissions() {
    log "Test des permissions..."
    
    # Vérifier les permissions du bundle
    local bundle_perms
    bundle_perms=$(ls -ld "$BUNDLE_PATH" | awk '{print $1}')
    
    if [[ "$bundle_perms" =~ ^d.*x.*x.*x ]]; then
        add_test_result "Permissions Bundle" "PASS" "Permissions correctes"
    else
        add_test_result "Permissions Bundle" "WARN" "Permissions: $bundle_perms"
    fi
    
    # Vérifier les permissions du binaire
    local binary_perms
    binary_perms=$(ls -l "$BINARY_PATH" | awk '{print $1}')
    
    if [[ "$binary_perms" =~ ^-.*x.*x.*x ]]; then
        add_test_result "Permissions Binary" "PASS" "Binaire exécutable"
    else
        add_test_result "Permissions Binary" "FAIL" "Binaire non exécutable: $binary_perms"
    fi
}

# Fonction pour afficher le résumé
show_summary() {
    echo
    echo "=== RÉSUMÉ DES TESTS ==="
    echo
    
    local pass_count=0
    local warn_count=0
    local fail_count=0
    
    for result in "${TEST_RESULTS[@]}"; do
        IFS='|' read -r test_name status message <<< "$result"
        
        case "$status" in
            "PASS") ((pass_count++)) ;;
            "WARN") ((warn_count++)) ;;
            "FAIL") ((fail_count++)) ;;
        esac
    done
    
    echo "Tests réussis: $pass_count"
    echo "Avertissements: $warn_count"
    echo "Échecs: $fail_count"
    echo
    
    if [[ $fail_count -eq 0 ]]; then
        success "Tous les tests critiques sont passés!"
        if [[ $warn_count -gt 0 ]]; then
            echo "Note: $warn_count avertissement(s) détecté(s) - voir détails ci-dessus"
        fi
    else
        fail "$fail_count test(s) critique(s) ont échoué"
        exit 1
    fi
}

# Fonction pour afficher l'aide
show_help() {
    echo "Usage: $0 <bundle_path> [options]"
    echo
    echo "Options:"
    echo "  --verbose    Affichage détaillé des tests"
    echo "  --help       Afficher cette aide"
    echo
    echo "Exemples:"
    echo "  $0 build/BUTT.app"
    echo "  $0 build/BUTT.app --verbose"
    echo
}

# Fonction principale
main() {
    # Vérification des arguments
    if [[ $# -lt 1 ]] || [[ "$1" == "--help" ]]; then
        show_help
        exit 0
    fi
    
    BUNDLE_PATH="$1"
    
    # Options
    if [[ "${2:-}" == "--verbose" ]]; then
        VERBOSE=true
    fi
    
    # Vérifications préliminaires
    if [[ ! -d "$BUNDLE_PATH" ]]; then
        error "Bundle introuvable: $BUNDLE_PATH"
    fi
    
    # Définir les chemins
    BINARY_PATH="$BUNDLE_PATH/Contents/MacOS/BUTT"
    FRAMEWORKS_PATH="$BUNDLE_PATH/Contents/Frameworks"
    RESOURCES_PATH="$BUNDLE_PATH/Contents/Resources"
    
    # Vérifier la structure du bundle
    if [[ ! -f "$BINARY_PATH" ]]; then
        error "Structure de bundle invalide: binaire introuvable"
    fi
    
    if [[ ! -d "$FRAMEWORKS_PATH" ]]; then
        error "Structure de bundle invalide: répertoire Frameworks introuvable"
    fi
    
    if [[ ! -d "$RESOURCES_PATH" ]]; then
        error "Structure de bundle invalide: répertoire Resources introuvable"
    fi
    
    echo "🧪 Test du bundle BUTT Enhanced"
    echo "Bundle: $BUNDLE_PATH"
    echo "Mode: $([ "$VERBOSE" == "true" ] && echo "Verbose" || echo "Normal")"
    echo
    
    # Exécuter les tests
    test_architecture
    test_dependencies
    test_code_signing
    test_resources
    test_permissions
    test_launch
    test_stereotool
    
    # Afficher le résumé
    show_summary
}

# Exécution
main "$@"
