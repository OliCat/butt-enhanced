#!/bin/bash

# 🚨 Emergency Audio Fix - BUTT/Qobuz Conflict
# ============================================

echo "🚨 Emergency Audio Fix - BUTT Enhanced"
echo "======================================"

# Diagnostic rapide
echo "🔍 Diagnostic Immédiat:"
BUTT_PID=$(pgrep -f "butt")
if [ ! -z "$BUTT_PID" ]; then
    BUTT_CPU=$(ps -p $BUTT_PID -o pcpu | tail -1 | xargs)
    BUTT_MEM=$(ps -p $BUTT_PID -o pmem | tail -1 | xargs)
    echo "   BUTT (PID $BUTT_PID): CPU=${BUTT_CPU}%, MEM=${BUTT_MEM}%"
    
    if (( $(echo "$BUTT_CPU > 70" | bc -l) )); then
        echo "   🔥 BUTT CPU CRITIQUE ! (>70%)"
        CRITICAL_CPU=1
    fi
else
    echo "   BUTT: Non actif"
fi

QOBUZ_PID=$(pgrep -f "Qobuz" | head -1)
if [ ! -z "$QOBUZ_PID" ]; then
    echo "   Qobuz (PID $QOBUZ_PID): Actif"
else
    echo "   Qobuz: Non actif"
fi

echo ""

# Solutions par priorité
echo "🛠️ Solutions Disponibles:"
echo "   1. Restart Qobuz uniquement (Safe)"
echo "   2. Optimiser BUTT + Restart Qobuz (Recommandé)" 
echo "   3. Restart BUTT + Qobuz (Interruption temporaire)"
echo "   4. Reset Audio System complet (Last resort)"

read -p "Choisir solution (1-4): " CHOICE

case $CHOICE in
    1)
        echo "🔄 Solution 1: Restart Qobuz Safe"
        ./restart_qobuz_clean.sh
        ;;
    
    2)
        echo "⚡ Solution 2: Optimisation BUTT + Restart Qobuz"
        
        # Réduire priorité BUTT
        if [ ! -z "$BUTT_PID" ]; then
            echo "📉 Réduction priorité BUTT..."
            sudo renice +15 $BUTT_PID
        fi
        
        # Kill processus audio non-essentiels
        echo "🧹 Nettoyage processus audio..."
        sudo pkill -f "VDCAssistant"
        sudo pkill -f "cameracaptured"
        
        # Restart Qobuz
        ./restart_qobuz_clean.sh
        ;;
    
    3)
        echo "🔄 Solution 3: Restart BUTT + Qobuz"
        echo "⚠️ ATTENTION: Interruption AES67 temporaire"
        read -p "Confirmer? (y/n): " CONFIRM
        
        if [ "$CONFIRM" = "y" ]; then
            echo "🔴 Arrêt BUTT..."
            pkill -f "butt"
            sleep 3
            
            echo "🔴 Arrêt Qobuz..."
            pkill -f "Qobuz"
            sleep 3
            
            echo "🔧 Reset Core Audio..."
            sudo pkill -HUP coreaudiod
            sleep 2
            
            echo "🚀 Redémarrage Qobuz..."
            open -a Qobuz
            sleep 5
            
            echo "🚀 Redémarrage BUTT..."
            cd /Users/ogrieco/stereoTool_testSDK/butt-enhanced
            nohup ./src/butt > /dev/null 2>&1 &
            
            echo "✅ Redémarrage complet terminé"
        fi
        ;;
    
    4)
        echo "🚨 Solution 4: Reset Audio System Complet"
        echo "⚠️ ATTENTION: Redémarrage de tous les services audio"
        read -p "Confirmer RESET COMPLET? (y/n): " CONFIRM
        
        if [ "$CONFIRM" = "y" ]; then
            echo "🔴 Arrêt toutes applications audio..."
            pkill -f "butt"
            pkill -f "Qobuz"
            pkill -f "Logic"
            pkill -f "GarageBand"
            pkill -f "Audacity"
            
            echo "🔧 Reset services audio système..."
            sudo pkill -HUP coreaudiod
            sudo launchctl stop com.apple.audio.coreaudiod
            sudo launchctl start com.apple.audio.coreaudiod
            
            echo "⏱️ Attente stabilisation (10s)..."
            sleep 10
            
            echo "🚀 Redémarrage applications..."
            open -a Qobuz
            sleep 5
            
            cd /Users/ogrieco/stereoTool_testSDK/butt-enhanced
            nohup ./src/butt > /dev/null 2>&1 &
            
            echo "✅ Reset complet terminé"
        fi
        ;;
    
    *)
        echo "❌ Choix invalide"
        exit 1
        ;;
esac

echo ""
echo "🎯 Status Final:"
sleep 3

if pgrep -f "butt" > /dev/null; then
    BUTT_CPU_FINAL=$(ps -p $(pgrep -f "butt") -o pcpu | tail -1 | xargs)
    echo "   BUTT: ✅ Actif (CPU: ${BUTT_CPU_FINAL}%)"
else
    echo "   BUTT: ❌ Inactif"
fi

if pgrep -f "Qobuz" > /dev/null; then
    echo "   Qobuz: ✅ Actif"
else
    echo "   Qobuz: ❌ Inactif"
fi

echo ""
echo "💡 Pour éviter futurs conflits:"
echo "   - Lancer BUTT AVANT Qobuz"
echo "   - Utiliser interface audio dédiée pour BUTT"
echo "   - Monitorer CPU usage: watch 'ps aux | grep butt'" 