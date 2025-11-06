#!/bin/bash

# 🚨 Fix BUTT Cleanup - Solution Immédiate
# ========================================

echo "🚨 Fix BUTT Cleanup - Solution Immédiate"
echo "========================================"
echo ""

# Fonction pour kill proprement BUTT
kill_butt_clean() {
    echo "🔪 Arrêt forcé de tous les processus BUTT..."
    
    # Kill par nom de processus
    pkill -f "./src/butt" 2>/dev/null
    pkill -f "butt" 2>/dev/null
    
    # Attendre 3 secondes
    sleep 3
    
    # Force kill si nécessaire
    pkill -9 -f "./src/butt" 2>/dev/null
    pkill -9 -f "butt" 2>/dev/null
    
    # Vérifier résultat
    REMAINING=$(pgrep -f "butt" | grep -v grep | wc -l)
    if [ $REMAINING -eq 0 ]; then
        echo "✅ Tous les processus BUTT arrêtés"
    else
        echo "⚠️ $REMAINING processus BUTT persistent"
        pgrep -f "butt" | while read pid; do
            echo "   PID $pid encore actif"
        done
    fi
}

# Fonction pour nettoyer les ressources réseau
cleanup_network() {
    echo "🌐 Nettoyage ressources réseau AES67..."
    
    # Identifier les connexions BUTT restantes
    AES67_CONNECTIONS=$(netstat -an | grep ":5004" | wc -l)
    SAP_CONNECTIONS=$(netstat -an | grep "sap.mcast.net" | wc -l)
    
    echo "   Connexions AES67 actives: $AES67_CONNECTIONS"
    echo "   Connexions SAP actives: $SAP_CONNECTIONS"
    
    if [ $AES67_CONNECTIONS -gt 0 ] || [ $SAP_CONNECTIONS -gt 0 ]; then
        echo "🔧 Reset Core Audio pour libérer ressources..."
        sudo pkill -HUP coreaudiod
        sleep 2
        echo "✅ Reset Core Audio terminé"
    fi
}

# Fonction pour restart BUTT proprement
restart_butt_clean() {
    echo "🚀 Redémarrage BUTT propre..."
    
    cd /Users/ogrieco/stereoTool_testSDK/butt-enhanced
    
    # Lancer en arrière-plan avec logs
    nohup ./src/butt > /tmp/butt_clean.log 2>&1 &
    NEW_PID=$!
    
    echo "   BUTT redémarré avec PID: $NEW_PID"
    
    # Attendre 3 secondes et vérifier
    sleep 3
    if ps -p $NEW_PID > /dev/null 2>&1; then
        echo "✅ BUTT démarré avec succès"
        
        # Vérifier qu'il n'y a qu'un seul processus
        BUTT_COUNT=$(pgrep -f "butt" | wc -l)
        echo "   Processus BUTT actifs: $BUTT_COUNT"
        
        if [ $BUTT_COUNT -eq 1 ]; then
            echo "✅ Un seul processus BUTT (optimal)"
        else
            echo "⚠️ Plusieurs processus BUTT détectés"
        fi
    else
        echo "❌ Échec démarrage BUTT"
        echo "📋 Logs de démarrage:"
        tail -10 /tmp/butt_clean.log
    fi
}

# ======================
# EXECUTION PRINCIPALE
# ======================

echo "🔍 Status initial:"
BUTT_PROCESSES=$(pgrep -f "butt" | wc -l)
echo "   Processus BUTT actifs: $BUTT_PROCESSES"

if [ $BUTT_PROCESSES -eq 0 ]; then
    echo "✅ Aucun processus BUTT actif"
    echo ""
    echo "🚀 Voulez-vous démarrer BUTT proprement? (y/n): "
    read -p "> " START_BUTT
    
    if [ "$START_BUTT" = "y" ]; then
        restart_butt_clean
    fi
    exit 0
fi

echo ""
echo "🛠️ Actions disponibles:"
echo "   1. Kill + Cleanup + Restart (Recommandé)"
echo "   2. Kill uniquement" 
echo "   3. Cleanup réseau uniquement"
echo "   4. Restart propre (sans kill)"
echo ""

read -p "Choisir action (1-4): " ACTION

case $ACTION in
    1)
        echo "🔄 Solution complète: Kill + Cleanup + Restart"
        kill_butt_clean
        echo ""
        cleanup_network
        echo ""
        restart_butt_clean
        ;;
    
    2)
        echo "🔪 Kill processus BUTT uniquement"
        kill_butt_clean
        ;;
    
    3)
        echo "🌐 Cleanup réseau uniquement"
        cleanup_network
        ;;
    
    4)
        echo "🚀 Restart BUTT (sans kill préalable)"
        restart_butt_clean
        ;;
    
    *)
        echo "❌ Option invalide"
        exit 1
        ;;
esac

echo ""
echo "📊 Status final:"
FINAL_PROCESSES=$(pgrep -f "butt" | wc -l)
echo "   Processus BUTT actifs: $FINAL_PROCESSES"

# Vérifier Qobuz après fix
sleep 2
if pgrep -f "Qobuz" > /dev/null; then
    echo "   Qobuz: ✅ Actif"
else
    echo "   Qobuz: ❌ Inactif - relancer si nécessaire"
fi

echo ""
echo "💡 Pour éviter futurs problèmes:"
echo "   1. Toujours fermer BUTT via interface (pas kill force)"
echo "   2. Attendre fermeture complète avant relancer"
echo "   3. Monitorer: watch 'ps aux | grep butt'"
echo "   4. Utiliser ce script en cas de problème"

echo ""
echo "✅ Fix terminé !" 