#!/bin/bash

echo "=== Test BUTT avec debug StereoTool ===" 
echo "Lancement de BUTT..."

# Démarrer BUTT et capturer la sortie
./src/butt -c ../test_config_no_preset.buttrc > test_debug.log 2>&1 &
BUTT_PID=$!

# Attendre un peu 
sleep 2

echo "BUTT démarré, PID: $BUTT_PID"
echo "Contenu du log au démarrage :"
cat test_debug.log

echo -e "\n=== Arrêt de BUTT ==="
kill $BUTT_PID 2>/dev/null

# Attendre que BUTT se ferme
sleep 1

echo "Log final :"
cat test_debug.log

# Nettoyer
rm -f test_debug.log
