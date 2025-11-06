#!/bin/bash

# 🚨 Diagnostic & Cleanup BUTT Avancé - Solution Complète
# ========================================================

echo "🚨 Diagnostic & Cleanup BUTT Avancé"
echo "==================================="
echo ""

# Configuration
BUTT_PROCESS_NAME="butt"
AES67_PORT="5004"
SAP_PORT="9875"
TIMEOUT_KILL=10
TIMEOUT_CLEANUP=5

# Couleurs pour output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction de logging
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

# Fonction pour analyser un processus BUTT
analyze_butt_process() {
    local pid=$1
    log_info "Analyse du processus BUTT PID $pid"
    
    # Informations de base
    local cpu_usage=$(ps -p $pid -o pcpu --no-headers 2>/dev/null | xargs)
    local mem_usage=$(ps -p $pid -o pmem --no-headers 2>/dev/null | xargs)
    local uptime=$(ps -p $pid -o etime --no-headers 2>/dev/null | xargs)
    
    echo "   CPU: ${cpu_usage:-N/A}% | MEM: ${mem_usage:-N/A}% | Uptime: ${uptime:-N/A}"
    
    # Connexions réseau
    local network_connections=$(lsof -i -P -p $pid 2>/dev/null | grep -E "(UDP|TCP)" | wc -l)
    echo "   Connexions réseau: $network_connections"
    
    if [ $network_connections -gt 0 ]; then
        echo "   Détails connexions:"
        lsof -i -P -p $pid 2>/dev/null | grep -E "(UDP|TCP)" | while read line; do
            echo "     $line"
        done
    fi
    
    # Threads
    local thread_count=$(ps -p $pid -o thcount --no-headers 2>/dev/null | xargs)
    echo "   Threads: $thread_count"
    
    # État du processus
    local state=$(ps -p $pid -o state --no-headers 2>/dev/null | xargs)
    case $state in
        Z) echo "   État: ZOMBIE (problème critique)" ;;
        D) echo "   État: UNINTERRUPTIBLE SLEEP (bloqué)" ;;
        S) echo "   État: SLEEPING (normal)" ;;
        R) echo "   État: RUNNING (normal)" ;;
        *) echo "   État: $state" ;;
    esac
}

# Fonction pour tuer un processus avec timeout
kill_process_with_timeout() {
    local pid=$1
    local signal=${2:-TERM}
    local timeout=${3:-$TIMEOUT_KILL}
    
    log_info "Envoi signal $signal au PID $pid"
    
    # Envoyer le signal
    kill -$signal $pid 2>/dev/null
    
    # Attendre avec timeout
    local count=0
    while [ $count -lt $timeout ]; do
        if ! ps -p $pid >/dev/null 2>&1; then
            log_success "Processus $pid terminé"
            return 0
        fi
        sleep 1
        count=$((count + 1))
    done
    
    log_warning "Timeout atteint pour PID $pid"
    return 1
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
                kill_process_with_timeout $pid TERM 3
            fi
        done
    fi
    
    if [ ! -z "$sap_processes" ]; then
        log_warning "Processus utilisant le port SAP ($SAP_PORT): $sap_processes"
        for pid in $sap_processes; do
            if ps -p $pid >/dev/null 2>&1; then
                kill_process_with_timeout $pid TERM 3
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

# Fonction pour nettoyer les processus BUTT
cleanup_butt_processes() {
    log_info "Nettoyage des processus BUTT"
    
    # Identifier tous les processus BUTT
    local butt_pids=$(pgrep -f "$BUTT_PROCESS_NAME" 2>/dev/null | sort -n)
    
    if [ -z "$butt_pids" ]; then
        log_success "Aucun processus BUTT trouvé"
        return 0
    fi
    
    local count=0
    for pid in $butt_pids; do
        count=$((count + 1))
        echo ""
        analyze_butt_process $pid
        
        # Essayer de tuer proprement d'abord
        if kill_process_with_timeout $pid TERM 5; then
            log_success "Processus $pid terminé proprement"
        else
            log_warning "Échec kill propre, tentative force"
            if kill_process_with_timeout $pid KILL 3; then
                log_success "Processus $pid forcé à se terminer"
            else
                log_error "Impossible de tuer le processus $pid"
                return 1
            fi
        fi
    done
    
    log_success "$count processus BUTT nettoyés"
    return 0
}

# Fonction pour vérifier l'état final
verify_cleanup() {
    log_info "Vérification de l'état final"
    
    local remaining_butt=$(pgrep -f "$BUTT_PROCESS_NAME" 2>/dev/null | wc -l)
    local remaining_aes67=$(lsof -i :$AES67_PORT 2>/dev/null | wc -l)
    local remaining_sap=$(lsof -i :$SAP_PORT 2>/dev/null | wc -l)
    
    echo "   Processus BUTT restants: $remaining_butt"
    echo "   Connexions AES67 restantes: $remaining_aes67"
    echo "   Connexions SAP restantes: $remaining_sap"
    
    if [ $remaining_butt -eq 0 ] && [ $remaining_aes67 -eq 0 ] && [ $remaining_sap -eq 0 ]; then
        log_success "Nettoyage complet réussi"
        return 0
    else
        log_warning "Nettoyage incomplet"
        return 1
    fi
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
        local butt_count=$(pgrep -f "$BUTT_PROCESS_NAME" 2>/dev/null | wc -l)
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

echo "🔍 Diagnostic initial:"
echo "======================"

# État initial
local initial_butt_count=$(pgrep -f "$BUTT_PROCESS_NAME" 2>/dev/null | wc -l)
local initial_aes67_count=$(lsof -i :$AES67_PORT 2>/dev/null | wc -l)
local initial_sap_count=$(lsof -i :$SAP_PORT 2>/dev/null | wc -l)

echo "   Processus BUTT: $initial_butt_count"
echo "   Connexions AES67: $initial_aes67_count"
echo "   Connexions SAP: $initial_sap_count"

# Analyser chaque processus BUTT
if [ $initial_butt_count -gt 0 ]; then
    echo ""
    echo "📊 Analyse des processus BUTT:"
    echo "=============================="
    
    pgrep -f "$BUTT_PROCESS_NAME" 2>/dev/null | while read pid; do
        analyze_butt_process $pid
        echo ""
    done
fi

echo ""
echo "🛠️ Actions disponibles:"
echo "   1. Diagnostic complet (Recommandé)"
echo "   2. Cleanup forcé + Restart"
echo "   3. Cleanup réseau uniquement"
echo "   4. Restart propre (sans cleanup)"
echo "   5. Diagnostic kernel (avancé)"
echo ""

read -p "Choisir action (1-5): " ACTION

case $ACTION in
    1)
        echo "🔍 Diagnostic complet"
        echo "===================="
        
        # Diagnostic détaillé
        echo ""
        echo "📊 État système:"
        echo "   Load average: $(uptime | awk -F'load average:' '{print $2}')"
        echo "   CPU usage: $(top -l 1 | grep "CPU usage" | awk '{print $3}')"
        echo "   Mémoire libre: $(vm_stat | grep "Pages free" | awk '{print $3}')"
        
        echo ""
        echo "🌐 Connexions réseau:"
        netstat -an | grep -E "($AES67_PORT|$SAP_PORT)" | head -10
        
        echo ""
        echo "🔧 État Core Audio:"
        ps aux | grep -E "(coreaudiod|VDCAssistant)" | grep -v grep
        
        echo ""
        echo "📋 Logs récents BUTT:"
        tail -20 /tmp/butt_clean_*.log 2>/dev/null | tail -10 || echo "   Aucun log récent trouvé"
        ;;
    
    2)
        echo "🔄 Cleanup forcé + Restart"
        echo "=========================="
        
        cleanup_network_resources
        echo ""
        cleanup_butt_processes
        echo ""
        sleep 2
        verify_cleanup
        echo ""
        restart_butt_clean
        ;;
    
    3)
        echo "🌐 Cleanup réseau uniquement"
        echo "=========================="
        cleanup_network_resources
        ;;
    
    4)
        echo "🚀 Restart propre"
        echo "================"
        restart_butt_clean
        ;;
    
    5)
        echo "🔧 Diagnostic kernel (avancé)"
        echo "============================"
        
        # Analyser les processus zombies
        local zombie_count=$(ps aux | grep -E "Z.*butt" | wc -l)
        echo "   Processus zombies BUTT: $zombie_count"
        
        if [ $zombie_count -gt 0 ]; then
            echo "   Détails zombies:"
            ps aux | grep -E "Z.*butt"
        fi
        
        # Analyser les locks kernel
        echo ""
        echo "🔒 Locks kernel:"
        sudo lsof +L1 2>/dev/null | grep butt | head -5
        
        # Analyser les sockets
        echo ""
        echo "🌐 Sockets détaillées:"
        sudo lsof -i -P | grep butt
        ;;
    
    *)
        log_error "Option invalide"
        exit 1
        ;;
esac

echo ""
echo "📊 Status final:"
echo "================"

local final_butt_count=$(pgrep -f "$BUTT_PROCESS_NAME" 2>/dev/null | wc -l)
local final_aes67_count=$(lsof -i :$AES67_PORT 2>/dev/null | wc -l)
local final_sap_count=$(lsof -i :$SAP_PORT 2>/dev/null | wc -l)

echo "   Processus BUTT: $final_butt_count"
echo "   Connexions AES67: $final_aes67_count"
echo "   Connexions SAP: $final_sap_count"

if [ $final_butt_count -eq 1 ] && [ $final_aes67_count -eq 0 ] && [ $final_sap_count -eq 0 ]; then
    log_success "État optimal atteint"
else
    log_warning "État non optimal - vérifier manuellement"
fi

echo ""
echo "💡 Recommandations:"
echo "   1. Toujours fermer BUTT via interface graphique"
echo "   2. Attendre 5 secondes avant relancer"
echo "   3. Monitorer: watch 'ps aux | grep butt'"
echo "   4. Utiliser ce script en cas de problème"
echo "   5. Vérifier logs: tail -f /tmp/butt_clean_*.log"

echo ""
log_success "Diagnostic terminé !" 