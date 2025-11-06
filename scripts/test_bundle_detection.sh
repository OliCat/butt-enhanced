#!/bin/bash

echo "🧪 Test de détection et fermeture des bundles BUTT"
echo "=================================================="

BUNDLE_PATH="build-x86_64/BUTT-Intel.app"
BUNDLE_EXE="$BUNDLE_PATH/Contents/MacOS/BUTT"

if [ ! -f "$BUNDLE_EXE" ]; then
    echo "❌ Bundle non trouvé: $BUNDLE_EXE"
    exit 1
fi

echo "✅ Bundle trouvé: $BUNDLE_PATH"
echo ""

# Test 1: Lancement direct de l'exécutable et vérification des logs
echo "📋 Test 1: Lancement direct de l'exécutable"
echo "Lancement du bundle en mode debug..."

# Lancer le bundle en arrière-plan et capturer sa sortie
"$BUNDLE_EXE" > bundle_test.log 2>&1 &
BUTT_PID=$!

echo "✅ BUTT lancé avec PID: $BUTT_PID"

# Attendre un peu pour que l'application se lance
sleep 2

# Vérifier si le processus existe encore
if kill -0 $BUTT_PID 2>/dev/null; then
    echo "✅ Processus BUTT actif"
    
    # Envoyer SIGTERM pour déclencher la fermeture
    echo "🔴 Envoi de SIGTERM au processus..."
    kill -TERM $BUTT_PID
    
    # Attendre la fermeture
    sleep 3
    
    # Vérifier si le processus s'est fermé
    if kill -0 $BUTT_PID 2>/dev/null; then
        echo "❌ Le processus existe toujours après SIGTERM"
        kill -KILL $BUTT_PID
        echo "🔴 Processus fermé avec SIGKILL"
    else
        echo "✅ SUCCÈS: Le processus s'est fermé avec SIGTERM"
    fi
else
    echo "⚠️  Le processus n'est plus actif (peut-être fermé rapidement)"
fi

echo ""
echo "📋 Logs du bundle:"
echo "=================="
if [ -f "bundle_test.log" ]; then
    head -50 bundle_test.log  # Montrer les premiers 50 lignes
    echo ""
    echo "=================="
    
    # Chercher des mots-clés importants dans les logs
    echo "🔍 Recherche de mots-clés dans les logs:"
    if grep -q "Bundle macOS détecté" bundle_test.log; then
        echo "✅ Détection de bundle macOS: OUI"
    else
        echo "❌ Détection de bundle macOS: NON"
    fi
    
    if grep -q "Configuration des gestionnaires de signaux" bundle_test.log; then
        echo "✅ Configuration des signaux: OUI"
    else
        echo "❌ Configuration des signaux: NON"
    fi
    
    if grep -q "Fermeture de bundle macOS détectée" bundle_test.log; then
        echo "✅ Déclenchement fermeture bundle: OUI"
    else
        echo "❌ Déclenchement fermeture bundle: NON"
    fi
    
else
    echo "Aucun log trouvé"
fi

# Test 2: Test avec open (comme le ferait un utilisateur)
echo ""
echo "📋 Test 2: Test avec 'open' (simulation utilisateur)"
echo "Lancement du bundle avec open..."

open "$BUNDLE_PATH"
sleep 3

# Vérifier les processus
REMAINING_PIDS=$(pgrep -f "BUTT-Intel.app")
if [ -n "$REMAINING_PIDS" ]; then
    echo "✅ Processus BUTT trouvé: $REMAINING_PIDS"
    echo "Test de fermeture manuelle (fermeture programmée dans 5 secondes)..."
    
    # Attendre un peu puis forcer la fermeture
    sleep 5
    echo "🔴 Fermeture forcée..."
    kill -TERM $REMAINING_PIDS
    sleep 2
    
    # Vérifier si fermé
    STILL_RUNNING=$(pgrep -f "BUTT-Intel.app")
    if [ -n "$STILL_RUNNING" ]; then
        echo "❌ Processus toujours actif, utilisation de SIGKILL"
        kill -KILL $STILL_RUNNING
    else
        echo "✅ Processus fermé avec SIGTERM"
    fi
else
    echo "❌ Aucun processus BUTT trouvé après 'open'"
fi

echo ""
echo "🎉 Test terminé!"

# Nettoyer
# rm -f bundle_test.log 