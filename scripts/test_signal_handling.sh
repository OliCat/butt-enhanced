#!/bin/bash

# Script de test pour vérifier la gestion des signaux dans BUTT
# Auteur: Assistant pour projet StereoTool SDK
# Version: 1.0

echo "🧪 Test de gestion des signaux BUTT"
echo "==================================="

# Compilation avec les nouveaux gestionnaires de signaux
echo "🔧 Compilation avec gestion des signaux..."
make clean
make -j$(sysctl -n hw.ncpu)

if [ $? -ne 0 ]; then
    echo "❌ Erreur de compilation"
    exit 1
fi

echo "✅ Compilation réussie"

# Test de la version src/
echo ""
echo "📋 Test de la version src/butt..."
echo "Lancement de BUTT (version src/)..."
echo "Fermez la fenêtre pour tester la fermeture propre"

# Lancer BUTT en arrière-plan
./src/butt &
BUTT_PID=$!

echo "BUTT lancé avec PID: $BUTT_PID"

# Attendre 5 secondes puis envoyer SIGTERM
sleep 5
echo "Envoi de SIGTERM à BUTT..."
kill -TERM $BUTT_PID

# Attendre la fermeture
wait $BUTT_PID
BUTT_EXIT_CODE=$?

echo "BUTT fermé avec code: $BUTT_EXIT_CODE"

if [ $BUTT_EXIT_CODE -eq 0 ]; then
    echo "✅ Fermeture propre réussie (version src/)"
else
    echo "⚠️  Fermeture avec code d'erreur: $BUTT_EXIT_CODE"
fi

echo ""
echo "🎯 Test terminé"
echo "Pour tester le bundle, lancez:"
echo "  open build-x86_64/BUTT-Intel.app"
echo "  puis fermez l'application normalement" 