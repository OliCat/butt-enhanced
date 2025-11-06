#!/usr/bin/env bash
set -euo pipefail

# Script de collecte des dépendances pour bundle macOS
# Collecte récursivement toutes les dépendances non-système d'un binaire
# Usage: collect_dependencies.sh <binary> <frameworks_dir>

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
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }

# Fonction pour collecter les dépendances récursivement
collect_deps_recursive() {
    local target="$1"
    local frameworks_dir="$2"
    local processed=("$3")
    local depth="${4:-0}"
    
    # Limiter la profondeur pour éviter les boucles infinies
    if [[ $depth -gt 10 ]]; then
        warn "Profondeur maximale atteinte pour $target"
        return 0
    fi
    
    # Indentation pour l'affichage
    local indent=""
    for ((i=0; i<depth; i++)); do
        indent+="  "
    done
    
    log "${indent}Analyse des dépendances de $(basename "$target")..."
    
    # Obtenir la liste des dépendances
    local deps
    deps=$(otool -L "$target" 2>/dev/null | grep -v "^$target:" | awk '{print $1}' || true)
    
    if [[ -z "$deps" ]]; then
        return 0
    fi
    
    echo "$deps" | while read -r dep; do
        # Skip les dépendances système et FLTK (pour éviter les conflits)
        if [[ "$dep" =~ ^/System/ ]] || [[ "$dep" =~ ^/usr/lib/ ]] || [[ "$dep" =~ libfltk ]]; then
            continue
        fi
        
        # Skip les chemins relatifs déjà traités
        if [[ "$dep" =~ ^@(executable_path|loader_path|rpath) ]]; then
            continue
        fi
        
        # Skip les dépendances déjà traitées
        local already_processed=false
        for processed_dep in "${processed[@]}"; do
            if [[ "$dep" == "$processed_dep" ]]; then
                already_processed=true
                break
            fi
        done
        
        if [[ "$already_processed" == "true" ]]; then
            continue
        fi
        
        # Ajouter à la liste des traitées
        processed+=("$dep")
        
        local dep_name=$(basename "$dep")
        local dest_path="$frameworks_dir/$dep_name"
        
        # Vérifier si la dépendance existe
        if [[ ! -f "$dep" ]]; then
            warn "${indent}  Dépendance introuvable: $dep"
            continue
        fi
        
        # Copier la librairie si pas déjà présente
        if [[ ! -f "$dest_path" ]]; then
            log "${indent}  Copie: $dep_name"
            cp "$dep" "$dest_path"
            
            # Fixer l'ID de la librairie
            install_name_tool -id "@executable_path/../Frameworks/$dep_name" "$dest_path" 2>/dev/null || {
                warn "${indent}    Échec de la correction de l'ID pour $dep_name"
            }
            
            # Récursion pour les dépendances de cette librairie
            collect_deps_recursive "$dest_path" "$frameworks_dir" "$(printf '%s\n' "${processed[@]}")" $((depth + 1))
        else
            log "${indent}  Déjà présent: $dep_name"
        fi
    done
}

# Fonction pour corriger les chemins de dépendances dans un binaire
fix_binary_dependencies() {
    local binary="$1"
    local frameworks_dir="$2"
    
    log "Correction des chemins de dépendances pour $(basename "$binary")..."
    
    # Obtenir la liste des dépendances
    local deps
    deps=$(otool -L "$binary" 2>/dev/null | grep -v "^$binary:" | awk '{print $1}' || true)
    
    if [[ -z "$deps" ]]; then
        return 0
    fi
    
    echo "$deps" | while read -r dep; do
        # Skip les dépendances système
        if [[ "$dep" =~ ^/System/ ]] || [[ "$dep" =~ ^/usr/lib/ ]]; then
            continue
        fi
        
        # Skip les chemins relatifs déjà corrects
        if [[ "$dep" =~ ^@(executable_path|loader_path|rpath) ]]; then
            continue
        fi
        
        local dep_name=$(basename "$dep")
        local new_path="@executable_path/../Frameworks/$dep_name"
        
        log "  Correction: $dep -> $new_path"
        install_name_tool -change "$dep" "$new_path" "$binary" 2>/dev/null || {
            warn "    Échec de la correction pour $dep"
        }
    done
}

# Fonction pour analyser les dépendances d'un binaire
analyze_dependencies() {
    local binary="$1"
    
    log "Analyse des dépendances de $(basename "$binary"):"
    echo
    
    # Architecture
    echo "Architecture:"
    lipo -info "$binary" 2>/dev/null || file "$binary"
    echo
    
    # Dépendances système
    echo "Dépendances système:"
    otool -L "$binary" 2>/dev/null | grep -E "^[[:space:]]*/System/|^[[:space:]]*/usr/lib/" || echo "  Aucune"
    echo
    
    # Dépendances non-système
    echo "Dépendances non-système:"
    otool -L "$binary" 2>/dev/null | grep -v -E "^[[:space:]]*/System/|^[[:space:]]*/usr/lib/|^$binary:" || echo "  Aucune"
    echo
    
    # Dépendances non-résolues
    echo "Dépendances non-résolues:"
    otool -L "$binary" 2>/dev/null | grep -v "@executable_path\|@loader_path\|@rpath\|/System/\|/usr/lib/\|^$binary:" || echo "  Aucune"
    echo
}

# Fonction pour nettoyer les dépendances dupliquées
cleanup_duplicates() {
    local frameworks_dir="$1"
    
    log "Nettoyage des doublons dans $frameworks_dir..."
    
    # Créer un répertoire temporaire
    local temp_dir
    temp_dir=$(mktemp -d)
    
    # Copier les librairies uniques
    local processed=()
    for lib in "$frameworks_dir"/*.dylib; do
        if [[ -f "$lib" ]]; then
            local lib_name=$(basename "$lib")
            local lib_path=$(readlink -f "$lib" 2>/dev/null || echo "$lib")
            
            # Vérifier si cette librairie a déjà été traitée
            local already_processed=false
            for processed_lib in "${processed[@]}"; do
                if [[ "$processed_lib" == "$lib_path" ]]; then
                    already_processed=true
                    break
                fi
            done
            
            if [[ "$already_processed" == "false" ]]; then
                cp "$lib" "$temp_dir/$lib_name"
                processed+=("$lib_path")
            else
                log "  Suppression du doublon: $lib_name"
            fi
        fi
    done
    
    # Remplacer le contenu du répertoire Frameworks
    rm -f "$frameworks_dir"/*.dylib
    mv "$temp_dir"/*.dylib "$frameworks_dir/" 2>/dev/null || true
    rmdir "$temp_dir"
    
    success "Nettoyage terminé"
}

# Fonction principale
main() {
    local binary="$1"
    local frameworks_dir="$2"
    
    # Vérifications
    if [[ $# -lt 2 ]]; then
        echo "Usage: $0 <binary> <frameworks_dir> [--analyze-only]"
        echo
        echo "Options:"
        echo "  --analyze-only    Analyser seulement les dépendances sans les copier"
        exit 1
    fi
    
    if [[ ! -f "$binary" ]]; then
        error "Binaire introuvable: $binary"
    fi
    
    if [[ ! -d "$(dirname "$frameworks_dir")" ]]; then
        error "Répertoire parent introuvable: $(dirname "$frameworks_dir")"
    fi
    
    # Créer le répertoire Frameworks
    mkdir -p "$frameworks_dir"
    
    echo "🔍 Collecte des dépendances pour $(basename "$binary")"
    echo "Répertoire cible: $frameworks_dir"
    echo
    
    # Mode analyse seulement
    if [[ "${3:-}" == "--analyze-only" ]]; then
        analyze_dependencies "$binary"
        return 0
    fi
    
    # Collecte récursive des dépendances
    collect_deps_recursive "$binary" "$frameworks_dir" "$binary" 0
    
    # Correction des chemins dans le binaire principal
    fix_binary_dependencies "$binary" "$frameworks_dir"
    
    # Correction des chemins dans toutes les librairies
    for lib in "$frameworks_dir"/*.dylib; do
        if [[ -f "$lib" ]]; then
            fix_binary_dependencies "$lib" "$frameworks_dir"
        fi
    done
    
    # Nettoyage des doublons
    cleanup_duplicates "$frameworks_dir"
    
    # Résumé
    echo
    success "=== RÉSUMÉ ==="
    echo "Binaire: $binary"
    echo "Frameworks: $frameworks_dir"
    echo "Librairies collectées: $(ls -1 "$frameworks_dir"/*.dylib 2>/dev/null | wc -l)"
    echo
    
    # Vérification finale
    echo "Vérification des dépendances non-résolues:"
    local unresolved
    unresolved=$(otool -L "$binary" 2>/dev/null | grep -v "@executable_path\|@loader_path\|@rpath\|/System/\|/usr/lib/\|^$binary:" || true)
    
    if [[ -n "$unresolved" ]]; then
        warn "Dépendances non-résolues détectées:"
        echo "$unresolved"
    else
        success "Toutes les dépendances sont résolues"
    fi
}

# Exécution
main "$@"
