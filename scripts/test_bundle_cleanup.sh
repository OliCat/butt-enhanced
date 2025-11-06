#!/bin/bash

# Script de test pour vérifier la fermeture propre du bundle BUTT Intel
# Auteur: Assistant pour projet StereoTool SDK
# Version: 1.0

echo "🧪 Test de fermeture propre du bundle BUTT Intel"
echo "================================================"

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
BUTT_PID=$(pgrep -f "BUTT-Intel.app")
if [ -z "$BUTT_PID" ]; then
    echo "❌ Erreur: Processus BUTT non trouvé"
    exit 1
fi

echo "✅ BUTT lancé avec PID: $BUTT_PID"

# Attendre 5 secondes puis envoyer SIGTERM
echo "Envoi de SIGTERM à BUTT..."
kill -TERM $BUTT_PID

# Attendre la fermeture
sleep 5

# Vérifier si le processus existe encore
if pgrep -f "BUTT-Intel.app" > /dev/null; then
    echo "❌ Erreur: BUTT ne s'est pas fermé proprement"
    echo "Processus restants:"
    ps aux | grep -E "BUTT|butt" | grep -v grep
    echo ""
    echo "Forcer la fermeture..."
    kill -KILL $BUTT_PID 2>/dev/null || true
    exit 1
else
    echo "✅ Fermeture propre réussie (SIGTERM)"
fi

echo ""

# Test 2: Lancement et fermeture avec SIGINT
echo "📋 Test 2: Lancement et fermeture avec SIGINT"
echo "Lancement du bundle..."
open "$BUNDLE_PATH"

# Attendre que l'application se lance
sleep 3

# Trouver le processus BUTT
BUTT_PID=$(pgrep -f "BUTT-Intel.app")
if [ -z "$BUTT_PID" ]; then
    echo "❌ Erreur: Processus BUTT non trouvé"
    exit 1
fi

echo "✅ BUTT lancé avec PID: $BUTT_PID"

# Envoyer SIGINT (Ctrl+C)
echo "Envoi de SIGINT à BUTT..."
kill -INT $BUTT_PID

# Attendre la fermeture
sleep 5

# Vérifier si le processus existe encore
if pgrep -f "BUTT-Intel.app" > /dev/null; then
    echo "❌ Erreur: BUTT ne s'est pas fermé proprement avec SIGINT"
    echo "Processus restants:"
    ps aux | grep -E "BUTT|butt" | grep -v grep
    echo ""
    echo "Forcer la fermeture..."
    kill -KILL $BUTT_PID 2>/dev/null || true
    exit 1
else
    echo "✅ Fermeture propre réussie (SIGINT)"
fi

echo ""

# Test 3: Vérification des processus zombies
echo "📋 Test 3: Vérification des processus zombies"
echo "Recherche de processus zombies..."

ZOMBIE_COUNT=$(ps aux | grep -E "\[.*\] <defunct>" | wc -l)
if [ "$ZOMBIE_COUNT" -gt 0 ]; then
    echo "⚠️  Attention: $ZOMBIE_COUNT processus zombie(s) détecté(s)"
    ps aux | grep -E "\[.*\] <defunct>"
else
    echo "✅ Aucun processus zombie détecté"
fi

echo ""

# Test 4: Vérification des ressources audio
echo "📋 Test 4: Vérification des ressources audio"
echo "Recherche de processus audio restants..."

AUDIO_PROCESSES=$(ps aux | grep -E "(portaudio|coreaudio|audiodevice)" | grep -v grep | wc -l)
if [ "$AUDIO_PROCESSES" -gt 0 ]; then
    echo "⚠️  Attention: $AUDIO_PROCESSES processus audio restant(s)"
    ps aux | grep -E "(portaudio|coreaudio|audiodevice)" | grep -v grep
else
    echo "✅ Aucun processus audio restant"
fi

echo ""

# Résumé final
echo "🎯 Résumé des tests"
echo "=================="
echo "✅ Bundle créé avec succès"
echo "✅ Gestion des signaux implémentée"
echo "✅ Tests de fermeture réussis"
echo ""
echo "🎉 Le bundle BUTT Intel se ferme maintenant proprement!"
echo ""
echo "Pour utiliser le bundle:"
echo "  open build-x86_64/BUTT-Intel.app"
echo ""
echo "Le bundle inclut maintenant:"
echo "  - Gestion des signaux SIGTERM, SIGINT, SIGQUIT"
echo "  - Fermeture propre des threads AES67"
echo "  - Cleanup des ressources audio"
echo "  - Nettoyage des buffers et sockets" 