#!/bin/bash

echo "Test de l'intégration StereoTool dans BUTT..."
echo "Lancement de BUTT avec configuration de test..."

# Rediriger toute la sortie vers un fichier de log
./src/butt -c test_config.buttrc > test_output.log 2>&1 &
BUTT_PID=$!

# Attendre 3 secondes
sleep 3

# Arrêter BUTT
kill $BUTT_PID 2>/dev/null

# Afficher les logs
echo "=== Messages de BUTT ==="
cat test_output.log

# Rechercher spécifiquement les messages StereoTool
echo -e "\n=== Messages StereoTool ==="
grep -i "stereo" test_output.log || echo "Aucun message StereoTool trouvé"

# Nettoyer
rm -f test_output.log
