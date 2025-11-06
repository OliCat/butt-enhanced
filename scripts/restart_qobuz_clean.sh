#!/bin/bash

# 🔄 Restart Qobuz Clean - Solution Immédiate
# ===========================================

echo "🔄 Redémarrage Clean Qobuz (Conflit BUTT)"
echo "========================================"

# Diagnostic initial
echo "📊 Status avant:"
BUTT_CPU=$(ps -p $(pgrep -f "butt") -o pcpu | tail -1 | xargs)
echo "   BUTT CPU: ${BUTT_CPU}%"

QOBUZ_PIDS=$(pgrep -f "Qobuz")
if [ ! -z "$QOBUZ_PIDS" ]; then
    echo "   Qobuz PIDs: $QOBUZ_PIDS"
else
    echo "   Qobuz: Non actif"
fi

echo ""

# 1. Kill tous les processus Qobuz
echo "🔪 Arrêt processus Qobuz..."
pkill -f "Qobuz"
sleep 3

# 2. Vérifier arrêt complet
if pgrep -f "Qobuz" > /dev/null; then
    echo "⚠️ Force kill nécessaire"
    pkill -9 -f "Qobuz"
    sleep 2
fi

# 3. Réduire priorité BUTT si CPU trop élevé
BUTT_PID=$(pgrep -f "butt")
if [ ! -z "$BUTT_PID" ]; then
    CURRENT_CPU=$(ps -p $BUTT_PID -o pcpu | tail -1 | xargs)
    if (( $(echo "$CURRENT_CPU > 50" | bc -l) )); then
        echo "📉 BUTT CPU trop élevé ($CURRENT_CPU%) - Réduction priorité"
        sudo renice +10 $BUTT_PID
    fi
fi

# 4. Reset Core Audio si nécessaire
echo "🔧 Reset Core Audio HAL..."
sudo pkill -HUP coreaudiod
sleep 1

# 5. Redémarrer Qobuz
echo "🚀 Redémarrage Qobuz..."
open -a Qobuz

# 6. Attendre et vérifier
sleep 5
if pgrep -f "Qobuz" > /dev/null; then
    echo "✅ Qobuz redémarré avec succès"
    echo ""
    echo "🎯 TESTER L'INTERFACE QOBUZ MAINTENANT"
    echo ""
    echo "💡 Si problème persiste:"
    echo "   - Fermer BUTT temporairement"  
    echo "   - Relancer Qobuz seul"
    echo "   - Puis relancer BUTT"
else
    echo "❌ Échec redémarrage Qobuz"
fi

echo ""
echo "📊 Status final:"
BUTT_CPU_FINAL=$(ps -p $(pgrep -f "butt") -o pcpu | tail -1 | xargs)
echo "   BUTT CPU: ${BUTT_CPU_FINAL}%"

if pgrep -f "Qobuz" > /dev/null; then
    echo "   Qobuz: ✅ Actif"
else
    echo "   Qobuz: ❌ Inactif"
fi 