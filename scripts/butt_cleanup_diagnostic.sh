#!/bin/bash

# 🔍 BUTT Cleanup Diagnostic - Détection Ressources Orphelines
# ===========================================================

echo "🔍 BUTT Cleanup Diagnostic - Ressources Orphelines"
echo "=================================================="
echo ""

# Fonction pour analyser un processus BUTT
analyze_butt_process() {
    local PID=$1
    echo "📊 Analyse processus BUTT PID: $PID"
    echo "--------------------------------"
    
    # Info processus
    ps -p $PID -o pid,ppid,pcpu,pmem,nlwp,time,command 2>/dev/null || {
        echo "❌ Processus $PID n'existe plus"
        return 1
    }
    
    echo ""
    echo "🔗 Connexions réseau ouvertes:"
    lsof -p $PID 2>/dev/null | grep -E "(TCP|UDP|socket)" | while read line; do
        echo "   $line"
    done
    
    echo ""
    echo "📁 Fichiers ouverts (audio/device):"
    lsof -p $PID 2>/dev/null | grep -E "(audio|Audio|device|dev)" | head -5 | while read line; do
        echo "   $line"
    done
    
    echo ""
    echo "🧵 Threads actifs:"
    ps -M -p $PID 2>/dev/null | wc -l | awk '{print "   Nombre threads: " $1-1}'
    
    echo ""
    echo "💾 Utilisation mémoire détaillée:"
    if command -v vmmap > /dev/null; then
        vmmap $PID 2>/dev/null | grep -E "(TOTAL|malloc|CoreAudio)" | head -3
    fi
    
    echo ""
    echo "⏱️ Temps CPU cumulé:"
    ps -p $PID -o time,cputime 2>/dev/null
    
    echo ""
}

# Fonction pour nettoyer un processus
cleanup_butt_process() {
    local PID=$1
    echo "🧹 Nettoyage processus BUTT PID: $PID"
    
    # Essayer SIGTERM d'abord
    echo "   Envoi SIGTERM..."
    kill -TERM $PID 2>/dev/null
    sleep 3
    
    # Vérifier s'il existe encore
    if ps -p $PID > /dev/null 2>&1; then
        echo "   ⚠️ Processus résiste, envoi SIGKILL..."
        kill -KILL $PID 2>/dev/null
        sleep 2
        
        if ps -p $PID > /dev/null 2>&1; then
            echo "   ❌ Impossible de tuer le processus $PID"
            return 1
        else
            echo "   ✅ Processus $PID tué (SIGKILL)"
        fi
    else
        echo "   ✅ Processus $PID terminé proprement (SIGTERM)"
    fi
}

# ==========================
# DIAGNOSTIC PRINCIPAL
# ==========================

echo "🔍 Recherche processus BUTT..."
BUTT_PIDS=$(pgrep -f "butt" | grep -v grep)

if [ -z "$BUTT_PIDS" ]; then
    echo "✅ Aucun processus BUTT trouvé"
    exit 0
fi

echo "📋 Processus BUTT détectés: $BUTT_PIDS"
echo ""

# Analyser chaque processus
for PID in $BUTT_PIDS; do
    analyze_butt_process $PID
    echo "========================================"
    echo ""
done

# ==========================
# TESTS RESSOURCES SYSTEME
# ==========================

echo "🌐 Test ressources réseau AES67:"
echo "--------------------------------"

# Vérifier port AES67
AES67_PORTS=$(netstat -an | grep ":5004" | wc -l)
echo "   Connexions port 5004: $AES67_PORTS"

# Vérifier multicast SAP
SAP_CONN=$(netstat -an | grep "sap.mcast.net" | wc -l)
echo "   Connexions SAP multicast: $SAP_CONN"

# Vérifier sockets UDP générales
UDP_SOCKETS=$(lsof -i UDP 2>/dev/null | grep butt | wc -l)
echo "   Sockets UDP BUTT: $UDP_SOCKETS"

echo ""

# ==========================
# DIAGNOSTIC CORE AUDIO
# ==========================

echo "🔊 Diagnostic Core Audio:"
echo "------------------------"

# Processus audio système
COREAUDIO_LOAD=$(ps aux | grep coreaudiod | grep -v grep | awk '{print $3}')
echo "   coreaudiod CPU: ${COREAUDIO_LOAD}%"

# Connexions audio BUTT
AUDIO_HANDLES=$(lsof 2>/dev/null | grep -E "(butt.*audio|butt.*Audio)" | wc -l)
echo "   Handles audio BUTT: $AUDIO_HANDLES"

echo ""

# ==========================
# SOLUTIONS PROPOSÉES
# ==========================

echo "🛠️ Solutions Disponibles:"
echo "========================"
echo ""
echo "1. 🔍 Diagnostic uniquement (déjà fait)"
echo "2. 🧹 Cleanup soft (SIGTERM)"
echo "3. 💀 Cleanup force (SIGKILL)"  
echo "4. 🔄 Cleanup complet + restart"
echo "5. 🚨 Reset audio système complet"
echo ""

read -p "Choisir action (1-5, ou q pour quitter): " ACTION

case $ACTION in
    1)
        echo "✅ Diagnostic terminé"
        ;;
    
    2)
        echo "🧹 Cleanup soft des processus BUTT..."
        for PID in $BUTT_PIDS; do
            kill -TERM $PID 2>/dev/null
            echo "   SIGTERM envoyé à PID $PID"
        done
        echo "⏱️ Attente 5s pour termination propre..."
        sleep 5
        
        # Vérifier résultats
        REMAINING=$(pgrep -f "butt" | wc -l)
        echo "📊 Processus BUTT restants: $REMAINING"
        ;;
    
    3)
        echo "💀 Cleanup force des processus BUTT..."
        for PID in $BUTT_PIDS; do
            cleanup_butt_process $PID
        done
        ;;
    
    4)
        echo "🔄 Cleanup complet + restart..."
        
        # Kill all BUTT
        for PID in $BUTT_PIDS; do
            cleanup_butt_process $PID
        done
        
        # Reset connexions réseau
        echo "🌐 Reset connexions réseau..."
        sudo pkill -HUP coreaudiod
        
        # Attendre stabilisation
        echo "⏱️ Attente stabilisation (5s)..."
        sleep 5
        
        # Restart BUTT clean
        echo "🚀 Redémarrage BUTT clean..."
        cd /Users/ogrieco/stereoTool_testSDK/butt-enhanced
        nohup ./src/butt > /tmp/butt_restart.log 2>&1 &
        
        NEW_PID=$!
        echo "✅ BUTT redémarré avec PID: $NEW_PID"
        ;;
    
    5)
        echo "🚨 Reset audio système complet..."
        echo "⚠️ ATTENTION: Ceci va redémarrer tous les services audio"
        read -p "Confirmer? (y/n): " CONFIRM
        
        if [ "$CONFIRM" = "y" ]; then
            # Kill toutes les apps audio
            pkill -f "butt"
            pkill -f "Logic"
            pkill -f "Audacity"
            pkill -f "Qobuz"
            
            # Reset services système
            sudo launchctl stop com.apple.audio.coreaudiod
            sudo launchctl start com.apple.audio.coreaudiod
            
            echo "✅ Reset audio système terminé"
        fi
        ;;
    
    q|Q)
        echo "👋 Diagnostic terminé"
        ;;
    
    *)
        echo "❌ Option invalide"
        ;;
esac

echo ""
echo "📋 Status final:"
FINAL_BUTT=$(pgrep -f "butt" | wc -l)
echo "   Processus BUTT actifs: $FINAL_BUTT"

if [ $FINAL_BUTT -eq 0 ]; then
    echo "✅ Aucun processus BUTT résiduel"
elif [ $FINAL_BUTT -eq 1 ]; then
    echo "✅ Un seul processus BUTT (normal)"
else
    echo "⚠️ Plusieurs processus BUTT détectés ($FINAL_BUTT)"
fi 