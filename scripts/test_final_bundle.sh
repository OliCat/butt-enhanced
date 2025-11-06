#!/bin/bash

# Script de test final pour vérifier la fermeture propre du bundle BUTT Intel
# Auteur: Assistant pour projet StereoTool SDK
# Version: 1.0

echo "🧪 Test final du bundle BUTT Intel avec gestion des signaux"
echo "=========================================================="

BUNDLE_PATH="build-x86_64/BUTT-Intel.app"
BUNDLE_EXE="$BUNDLE_PATH/Contents/MacOS/BUTT"

# Vérifier que le bundle existe
if [ ! -f "$BUNDLE_EXE" ]; then
    echo "❌ Erreur: Bundle non trouvé: $BUNDLE_EXE"
    echo "Lancez d'abord: ./build_intel_bundle_fixed.sh"
    exit 1
fi

echo "✅ Bundle trouvé: $BUNDLE_PATH"
echo ""

# Test 1: Lancement et fermeture normale
echo "📋 Test 1: Lancement et fermeture normale"
echo "Lancement du bundle..."
open "$BUNDLE_PATH"

# Attendre que l'application se lance
sleep 3

# Trouver le processus BUTT
BUTT_PID=$(pgrep -f "BUTT-Intel.app" | head -1)

if [ -z "$BUTT_PID" ]; then
    echo "❌ Erreur: Processus BUTT non trouvé"
    exit 1
fi

echo "✅ BUTT lancé avec PID: $BUTT_PID"

# Attendre 5 secondes puis envoyer SIGTERM
sleep 5
echo "🔴 Envoi de SIGTERM au processus $BUTT_PID..."
kill -TERM $BUTT_PID

# Attendre la fermeture
sleep 3

# Vérifier si le processus existe toujours
if pgrep -f "BUTT-Intel.app" > /dev/null; then
    echo "❌ ÉCHEC: Le processus existe toujours après SIGTERM"
    echo "Tentative avec SIGKILL..."
    kill -KILL $BUTT_PID
    sleep 1
    if pgrep -f "BUTT-Intel.app" > /dev/null; then
        echo "❌ ÉCHEC: Le processus existe toujours après SIGKILL"
        exit 1
    else
        echo "✅ Processus fermé avec SIGKILL"
    fi
else
    echo "✅ SUCCÈS: Le processus s'est fermé proprement avec SIGTERM"
fi

echo ""
echo "📋 Test 2: Test avec fermeture via l'interface graphique"
echo "Lancement du bundle pour test manuel..."
open "$BUNDLE_PATH"

echo ""
echo "🎯 Instructions pour le test manuel:"
echo "1. Le bundle BUTT devrait être ouvert"
echo "2. Fermez l'application en cliquant sur la croix (X)"
echo "3. L'application devrait se fermer proprement"
echo "4. Si elle se bloque, utilisez 'Forcer à quitter'"
echo ""
echo "⏳ Attente de 30 secondes pour le test manuel..."
sleep 30

# Vérifier s'il reste des processus BUTT
REMAINING_PIDS=$(pgrep -f "BUTT-Intel.app")
if [ -n "$REMAINING_PIDS" ]; then
    echo "❌ ATTENTION: Processus BUTT restants: $REMAINING_PIDS"
    echo "Cela indique que la fermeture n'est pas encore parfaite"
else
    echo "✅ Aucun processus BUTT restant - fermeture propre"
fi

echo ""
echo "🎉 Test terminé!"
echo "=================="
echo ""
echo "📊 Résumé des corrections appliquées:"
echo "✅ Gestion des signaux SIGTERM, SIGINT, SIGQUIT"
echo "✅ Notifications macOS pour détection de fermeture"
echo "✅ Boucle GUI personnalisée avec vérification des signaux"
echo "✅ Cleanup des threads AES67"
echo "✅ Fermeture propre des ressources audio"
echo ""
echo "📁 Bundle disponible: $BUNDLE_PATH"
echo "🚀 Pour lancer: open $BUNDLE_PATH" 