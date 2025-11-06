#!/bin/bash

# 🚨 Solution Finale - Élimination Zombie BUTT
# ============================================

echo "🚨 Solution Finale - Élimination Zombie BUTT"
echo "============================================"
echo ""

# Configuration
ZOMBIE_PID="82519"
NEW_BUTT_PID="53512"

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

# Fonction pour analyser l'état actuel
analyze_current_state() {
    log_info "Analyse de l'état actuel..."
    
    # Vérifier le zombie
    if ps -p $ZOMBIE_PID >/dev/null 2>&1; then
        local state=$(ps -p $ZOMBIE_PID -o state --no-headers 2>/dev/null | xargs)
        log_warning "Zombie PID $ZOMBIE_PID toujours présent (état: $state)"
        
        # Analyser les ressources du zombie
        local open_files=$(lsof -p $ZOMBIE_PID 2>/dev/null | wc -l)
        local network_connections=$(lsof -i -P -p $ZOMBIE_PID 2>/dev/null | grep -E "(UDP|TCP)" | wc -l)
        
        echo "   Fichiers ouverts: $open_files"
        echo "   Connexions réseau: $network_connections"
        
        if [ $network_connections -gt 0 ]; then
            echo "   Connexions réseau du zombie:"
            lsof -i -P -p $ZOMBIE_PID 2>/dev/null | grep -E "(UDP|TCP)" | head -5
        fi
    else
        log_success "Zombie PID $ZOMBIE_PID n'existe plus"
    fi
    
    # Vérifier le nouveau BUTT
    if ps -p $NEW_BUTT_PID >/dev/null 2>&1; then
        local cpu_usage=$(ps -p $NEW_BUTT_PID -o pcpu --no-headers 2>/dev/null | xargs)
        local mem_usage=$(ps -p $NEW_BUTT_PID -o pmem --no-headers 2>/dev/null | xargs)
        log_success "Nouveau BUTT PID $NEW_BUTT_PID actif (CPU: ${cpu_usage:-N/A}%, MEM: ${mem_usage:-N/A}%)"
    else
        log_error "Nouveau BUTT PID $NEW_BUTT_PID non trouvé"
    fi
    
    # Vérifier les connexions AES67
    local aes67_connections=$(lsof -i :5004 2>/dev/null | wc -l)
    local sap_connections=$(lsof -i :9875 2>/dev/null | wc -l)
    
    echo "   Connexions AES67: $aes67_connections"
    echo "   Connexions SAP: $sap_connections"
}

# Fonction pour forcer la libération du zombie via kernel
force_zombie_release() {
    local pid=$1
    log_info "Tentative de libération forcée du zombie PID $pid via kernel"
    
    # Méthode 1: Reset du processus parent
    local ppid=$(ps -p $pid -o ppid --no-headers 2>/dev/null | xargs)
    if [ ! -z "$ppid" ] && [ "$ppid" != "1" ]; then
        log_info "Reset du processus parent PID $ppid"
        sudo kill -HUP $ppid 2>/dev/null
        sleep 3
        
        if ! ps -p $pid >/dev/null 2>&1; then
            log_success "Zombie libéré via reset parent"
            return 0
        fi
    fi
    
    # Méthode 2: Reset Core Audio complet
    log_info "Reset Core Audio complet..."
    sudo pkill -HUP coreaudiod 2>/dev/null
    sudo launchctl stop com.apple.audio.coreaudiod 2>/dev/null
    sleep 2
    sudo launchctl start com.apple.audio.coreaudiod 2>/dev/null
    sleep 5
    
    if ! ps -p $pid >/dev/null 2>&1; then
        log_success "Zombie libéré via reset Core Audio"
        return 0
    fi
    
    # Méthode 3: Reset kernel audio
    log_warning "Reset kernel audio..."
    sudo pkill -HUP kernel_task 2>/dev/null
    sleep 3
    
    if ! ps -p $pid >/dev/null 2>&1; then
        log_success "Zombie libéré via reset kernel"
        return 0
    fi
    
    # Méthode 4: Reset complet système audio
    log_warning "Reset complet système audio..."
    sudo pkill -f "butt" 2>/dev/null
    sudo pkill -f "Qobuz" 2>/dev/null
    sudo pkill -f "Logic" 2>/dev/null
    sudo pkill -f "GarageBand" 2>/dev/null
    sudo pkill -f "Audacity" 2>/dev/null
    
    sudo pkill -HUP coreaudiod 2>/dev/null
    sudo launchctl stop com.apple.audio.coreaudiod 2>/dev/null
    sudo launchctl start com.apple.audio.coreaudiod 2>/dev/null
    
    sleep 10
    
    if ! ps -p $pid >/dev/null 2>&1; then
        log_success "Zombie libéré via reset complet"
        return 0
    fi
    
    log_error "Impossible de libérer le zombie PID $pid"
    return 1
}

# Fonction pour redémarrer BUTT proprement
restart_butt_final() {
    log_info "Redémarrage final de BUTT"
    
    cd /Users/ogrieco/stereoTool_testSDK/butt-enhanced
    
    # Arrêter tous les processus BUTT existants
    pkill -f "butt" 2>/dev/null
    sleep 3
    
    # Vérifier qu'ils sont arrêtés
    local remaining=$(pgrep -f "butt" 2>/dev/null | wc -l)
    if [ $remaining -gt 0 ]; then
        log_warning "$remaining processus BUTT persistent, force kill"
        pkill -9 -f "butt" 2>/dev/null
        sleep 2
    fi
    
    # Lancer BUTT avec logs détaillés
    nohup ./src/butt > /tmp/butt_final_$(date +%s).log 2>&1 &
    local new_pid=$!
    
    log_info "BUTT redémarré avec PID: $new_pid"
    
    # Attendre et vérifier
    sleep 5
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

echo "🔍 Diagnostic initial..."
echo "======================="

analyze_current_state

echo ""
echo "🛠️ Solutions disponibles:"
echo "   1. Libération forcée zombie + Restart"
echo "   2. Reset complet système audio"
echo "   3. Redémarrage BUTT uniquement"
echo "   4. Diagnostic avancé kernel"
echo ""

read -p "Choisir solution (1-4): " ACTION

case $ACTION in
    1)
        echo "🔪 Libération forcée zombie + Restart"
        echo "==================================="
        
        if ps -p $ZOMBIE_PID >/dev/null 2>&1; then
            force_zombie_release $ZOMBIE_PID
        fi
        
        echo ""
        restart_butt_final
        ;;
    
    2)
        echo "🚨 Reset complet système audio"
        echo "=============================="
        
        log_info "Arrêt de tous les processus audio..."
        sudo pkill -f "butt" 2>/dev/null
        sudo pkill -f "Qobuz" 2>/dev/null
        sudo pkill -f "Logic" 2>/dev/null
        sudo pkill -f "GarageBand" 2>/dev/null
        sudo pkill -f "Audacity" 2>/dev/null
        
        log_info "Reset Core Audio..."
        sudo pkill -HUP coreaudiod 2>/dev/null
        sudo launchctl stop com.apple.audio.coreaudiod 2>/dev/null
        sudo launchctl start com.apple.audio.coreaudiod 2>/dev/null
        
        log_info "Attente stabilisation (15s)..."
        sleep 15
        
        log_info "Redémarrage BUTT..."
        restart_butt_final
        ;;
    
    3)
        echo "🚀 Redémarrage BUTT uniquement"
        echo "============================="
        restart_butt_final
        ;;
    
    4)
        echo "🔧 Diagnostic avancé kernel"
        echo "==========================="
        
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
        
        # Analyser les processus en état D
        echo ""
        echo "😴 Processus en état D (bloqués):"
        ps aux | grep -E "D.*butt" || echo "   Aucun processus BUTT en état D"
        
        # Analyser les threads
        echo ""
        echo "🧵 Threads BUTT:"
        ps -M | grep butt | head -5
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
FINAL_AES67_COUNT=$(lsof -i :5004 2>/dev/null | wc -l)
FINAL_SAP_COUNT=$(lsof -i :9875 2>/dev/null | wc -l)

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
echo "   2. Vérifier logs: tail -f /tmp/butt_final_*.log"
echo "   3. Utiliser ce script en cas de problème"
echo "   4. Considérer un redémarrage système si problème persiste"

echo ""
log_success "Solution finale appliquée !" 