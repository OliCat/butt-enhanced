#!/bin/bash

# 🚨 Solution Immédiate - Processus Zombie BUTT
# =============================================

echo "🚨 Solution Immédiate - Processus Zombie BUTT"
echo "============================================="
echo ""

# Configuration
ZOMBIE_PID="82519"
AES67_PORT="5004"
SAP_PORT="9875"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Fonction pour analyser le zombie
analyze_zombie() {
    local pid=$1
    log_info "Analyse du processus zombie PID $pid"
    
    # État du processus
    local state=$(ps -p $pid -o state --no-headers 2>/dev/null | xargs)
    echo "   État: $state"
    
    # Connexions réseau
    local network_connections=$(lsof -i -P -p $pid 2>/dev/null | grep -E "(UDP|TCP)" | wc -l)
    echo "   Connexions réseau: $network_connections"
    
    if [ $network_connections -gt 0 ]; then
        echo "   Détails connexions:"
        lsof -i -P -p $pid 2>/dev/null | grep -E "(UDP|TCP)" | while read line; do
            echo "     $line"
        done
    fi
    
    # Fichiers ouverts
    local open_files=$(lsof -p $pid 2>/dev/null | wc -l)
    echo "   Fichiers ouverts: $open_files"
}

# Fonction pour nettoyer les ressources réseau
cleanup_network_resources() {
    log_info "Nettoyage des ressources réseau"
    
    # Identifier les processus utilisant les ports AES67/SAP
    local aes67_processes=$(lsof -i :$AES67_PORT 2>/dev/null | grep LISTEN | awk '{print $2}' | sort -u)
    local sap_processes=$(lsof -i :$SAP_PORT 2>/dev/null | grep LISTEN | awk '{print $2}' | sort -u)
    
    if [ ! -z "$aes67_processes" ]; then
        log_warning "Processus utilisant le port AES67 ($AES67_PORT): $aes67_processes"
        for pid in $aes67_processes; do
            if ps -p $pid >/dev/null 2>&1; then
                log_info "Arrêt du processus $pid"
                kill -TERM $pid 2>/dev/null
                sleep 2
                if ps -p $pid >/dev/null 2>&1; then
                    log_warning "Force kill du processus $pid"
                    kill -KILL $pid 2>/dev/null
                fi
            fi
        done
    fi
    
    if [ ! -z "$sap_processes" ]; then
        log_warning "Processus utilisant le port SAP ($SAP_PORT): $sap_processes"
        for pid in $sap_processes; do
            if ps -p $pid >/dev/null 2>&1; then
                log_info "Arrêt du processus $pid"
                kill -TERM $pid 2>/dev/null
                sleep 2
                if ps -p $pid >/dev/null 2>&1; then
                    log_warning "Force kill du processus $pid"
                    kill -KILL $pid 2>/dev/null
                fi
            fi
        done
    fi
    
    # Reset Core Audio si nécessaire
    local audio_conflicts=$(lsof -i -P 2>/dev/null | grep -E "(coreaudiod|VDCAssistant)" | wc -l)
    if [ $audio_conflicts -gt 0 ]; then
        log_info "Conflits audio détectés, reset Core Audio"
        sudo pkill -HUP coreaudiod 2>/dev/null
        sleep 2
    fi
}

# Fonction pour forcer la libération du zombie
force_zombie_cleanup() {
    local pid=$1
    log_info "Tentative de libération forcée du zombie PID $pid"
    
    # Méthode 1: Kill avec différents signaux
    for signal in TERM INT QUIT KILL; do
        log_info "Envoi signal $signal au PID $pid"
        kill -$signal $pid 2>/dev/null
        sleep 1
        
        if ! ps -p $pid >/dev/null 2>&1; then
            log_success "Zombie libéré avec signal $signal"
            return 0
        fi
    done
    
    # Méthode 2: Reset du processus parent
    local ppid=$(ps -p $pid -o ppid --no-headers 2>/dev/null | xargs)
    if [ ! -z "$ppid" ] && [ "$ppid" != "1" ]; then
        log_info "Reset du processus parent PID $ppid"
        kill -HUP $ppid 2>/dev/null
        sleep 2
        
        if ! ps -p $pid >/dev/null 2>&1; then
            log_success "Zombie libéré via reset parent"
            return 0
        fi
    fi
    
    # Méthode 3: Reset kernel (dernière chance)
    log_warning "Tentative de reset kernel pour libérer le zombie"
    sudo pkill -HUP kernel_task 2>/dev/null
    sleep 3
    
    if ! ps -p $pid >/dev/null 2>&1; then
        log_success "Zombie libéré via reset kernel"
        return 0
    fi
    
    log_error "Impossible de libérer le zombie PID $pid"
    return 1
}

# Fonction pour redémarrer BUTT proprement
restart_butt_clean() {
    log_info "Redémarrage propre de BUTT"
    
    cd /Users/ogrieco/stereoTool_testSDK/butt-enhanced
    
    # Vérifier que le binaire existe
    if [ ! -f "./src/butt" ]; then
        log_error "Binaire BUTT non trouvé"
        return 1
    fi
    
    # Lancer en arrière-plan avec logs
    nohup ./src/butt > /tmp/butt_clean_$(date +%s).log 2>&1 &
    local new_pid=$!
    
    log_info "BUTT redémarré avec PID: $new_pid"
    
    # Attendre et vérifier
    sleep 3
    if ps -p $new_pid >/dev/null 2>&1; then
        local cpu_usage=$(ps -p $new_pid -o pcpu --no-headers 2>/dev/null | xargs)
        log_success "BUTT démarré avec succès (CPU: ${cpu_usage:-N/A}%)"
        
        # Vérifier qu'il n'y a qu'un seul processus
        local butt_count=$(pgrep -f "butt" 2>/dev/null | wc -l)
        if [ $butt_count -eq 1 ]; then
            log_success "Un seul processus BUTT (optimal)"
        else
            log_warning "$butt_count processus BUTT détectés"
        fi
        return 0
    else
        log_error "Échec démarrage BUTT"
        return 1
    fi
}

# ======================
# EXECUTION PRINCIPALE
# ======================

echo "🔍 Diagnostic du zombie..."
echo "=========================="

# Vérifier si le zombie existe toujours
if ps -p $ZOMBIE_PID >/dev/null 2>&1; then
    analyze_zombie $ZOMBIE_PID
    echo ""
else
    log_success "Zombie PID $ZOMBIE_PID n'existe plus"
    ZOMBIE_PID=""
fi

# Vérifier s'il y a d'autres processus BUTT
OTHER_BUTT_PIDS=$(pgrep -f "butt" 2>/dev/null | grep -v $ZOMBIE_PID | tr '\n' ' ')
if [ ! -z "$OTHER_BUTT_PIDS" ]; then
    log_warning "Autres processus BUTT détectés: $OTHER_BUTT_PIDS"
    for pid in $OTHER_BUTT_PIDS; do
        analyze_zombie $pid
        echo ""
    done
fi

echo ""
echo "🛠️ Solutions disponibles:"
echo "   1. Nettoyage réseau + Reset Core Audio"
echo "   2. Libération forcée zombie + Restart"
echo "   3. Reset complet système audio"
echo "   4. Redémarrage BUTT (sans cleanup)"
echo ""

read -p "Choisir solution (1-4): " ACTION

case $ACTION in
    1)
        echo "🌐 Nettoyage réseau + Reset Core Audio"
        echo "====================================="
        cleanup_network_resources
        ;;
    
    2)
        echo "🔪 Libération forcée zombie + Restart"
        echo "===================================="
        
        if [ ! -z "$ZOMBIE_PID" ]; then
            force_zombie_cleanup $ZOMBIE_PID
        fi
        
        for pid in $OTHER_BUTT_PIDS; do
            force_zombie_cleanup $pid
        done
        
        echo ""
        cleanup_network_resources
        echo ""
        restart_butt_clean
        ;;
    
    3)
        echo "🚨 Reset complet système audio"
        echo "=============================="
        
        log_info "Arrêt de tous les processus audio..."
        pkill -f "butt" 2>/dev/null
        pkill -f "Qobuz" 2>/dev/null
        pkill -f "Logic" 2>/dev/null
        pkill -f "GarageBand" 2>/dev/null
        pkill -f "Audacity" 2>/dev/null
        
        log_info "Reset Core Audio..."
        sudo pkill -HUP coreaudiod 2>/dev/null
        sudo launchctl stop com.apple.audio.coreaudiod 2>/dev/null
        sudo launchctl start com.apple.audio.coreaudiod 2>/dev/null
        
        log_info "Attente stabilisation (10s)..."
        sleep 10
        
        log_info "Redémarrage BUTT..."
        restart_butt_clean
        ;;
    
    4)
        echo "🚀 Redémarrage BUTT (sans cleanup)"
        echo "=================================="
        restart_butt_clean
        ;;
    
    *)
        log_error "Option invalide"
        exit 1
        ;;
esac

echo ""
echo "📊 Status final:"
echo "================"

FINAL_BUTT_COUNT=$(pgrep -f "butt" 2>/dev/null | wc -l)
FINAL_AES67_COUNT=$(lsof -i :$AES67_PORT 2>/dev/null | wc -l)
FINAL_SAP_COUNT=$(lsof -i :$SAP_PORT 2>/dev/null | wc -l)

echo "   Processus BUTT: $FINAL_BUTT_COUNT"
echo "   Connexions AES67: $FINAL_AES67_COUNT"
echo "   Connexions SAP: $FINAL_SAP_COUNT"

if [ $FINAL_BUTT_COUNT -eq 1 ] && [ $FINAL_AES67_COUNT -eq 0 ] && [ $FINAL_SAP_COUNT -eq 0 ]; then
    log_success "État optimal atteint"
else
    log_warning "État non optimal - vérifier manuellement"
fi

echo ""
echo "💡 Recommandations:"
echo "   1. Monitorer: watch 'ps aux | grep butt'"
echo "   2. Vérifier logs: tail -f /tmp/butt_clean_*.log"
echo "   3. Utiliser ce script en cas de problème"
echo "   4. Considérer un redémarrage système si problème persiste"

echo ""
log_success "Solution appliquée !" 