#!/bin/bash

# Diagnostic de la distorsion audio - BUTT Enhanced
# Auteur: Assistant IA
# Date: $(date)

echo "=== DIAGNOSTIC DE LA DISTORSION AUDIO ==="
echo "Analyse approfondie du problème de distorsion"
echo

# Vérifier que nous sommes dans le bon répertoire
if [ ! -f "src/port_audio.cpp" ]; then
    echo "ERREUR: Ce script doit être exécuté depuis le répertoire butt-enhanced"
    exit 1
fi

echo "1. Analyse du callback snd_callback..."

# Vérifier si pa_new_frames est commenté
if grep -q "pa_new_frames = 1;" src/port_audio.cpp; then
    echo "✓ pa_new_frames est activé dans le callback"
else
    echo "✗ pa_new_frames est commenté dans le callback"
fi

# Vérifier la capture des données audio
if grep -q "rb_write(&pa_pcm_rb," src/port_audio.cpp; then
    echo "✓ Capture des données audio active"
else
    echo "✗ Capture des données audio manquante"
fi

echo
echo "2. Analyse du thread de mixage..."

# Vérifier le traitement DSP
if grep -q "streaming_dsp->processSamples" src/port_audio.cpp; then
    echo "✓ Traitement DSP streaming actif"
else
    echo "✗ Traitement DSP streaming manquant"
fi

if grep -q "recording_dsp->processSamples" src/port_audio.cpp; then
    echo "✓ Traitement DSP enregistrement actif"
else
    echo "✗ Traitement DSP enregistrement manquant"
fi

# Vérifier l'envoi vers Core Audio
if grep -q "core_audio_output_send" src/port_audio.cpp; then
    echo "✓ Envoi vers Core Audio actif"
else
    echo "✗ Envoi vers Core Audio manquant"
fi

echo
echo "3. Analyse des variables critiques..."

# Vérifier les variables globales
echo "Variables globales audio:"
grep -E "(pa_frames|pa_pcm_buf|stream_buf|record_buf)" src/port_audio.cpp | head -5

echo
echo "4. Analyse des buffers..."

# Vérifier l'initialisation des buffers
if grep -q "rb_init" src/port_audio.cpp; then
    echo "✓ Initialisation des ring buffers active"
else
    echo "✗ Initialisation des ring buffers manquante"
fi

echo
echo "5. Diagnostic du problème de distorsion..."

echo "HYPOTHÈSES POSSIBLES:"
echo "====================="
echo "1. Buffer underrun/overrun"
echo "2. Problème de synchronisation des threads"
echo "3. Problème de gestion mémoire"
echo "4. Problème de format audio"
echo "5. Problème de latence audio"

echo
echo "6. Tests recommandés..."

echo "Test 1: Vérifier les logs système"
echo "--------------------------------"
echo "Lancer BUTT et vérifier les logs:"
echo "log show --predicate 'process == \"BUTT\"' --last 5m"

echo
echo "Test 2: Vérifier l'utilisation CPU"
echo "---------------------------------"
echo "top -pid \$(pgrep butt)"

echo
echo "Test 3: Vérifier l'utilisation mémoire"
echo "-------------------------------------"
echo "ps -o pid,vsz,rss,command -p \$(pgrep butt)"

echo
echo "Test 4: Vérifier les périphériques audio"
echo "----------------------------------------"
echo "system_profiler SPAudioDataType"

echo
echo "7. Solutions possibles..."

echo "Solution 1: Augmenter la taille des buffers"
echo "-------------------------------------------"
echo "- Modifier cfg.audio.buffer_ms dans la configuration"
echo "- Tester avec 50ms au lieu de 20ms"

echo
echo "Solution 2: Vérifier la synchronisation"
echo "--------------------------------------"
echo "- S'assurer que pa_new_frames est correctement géré"
echo "- Vérifier la synchronisation des threads"

echo
echo "Solution 3: Vérifier le format audio"
echo "-----------------------------------"
echo "- Tester avec différents échantillonnages"
echo "- Vérifier la compatibilité des périphériques"

echo
echo "8. Instructions de test..."

echo "Pour tester les corrections:"
echo "1. Compiler BUTT: make"
echo "2. Lancer BUTT: ./butt"
echo "3. Activer Core Audio Output"
echo "4. Sélectionner un périphérique"
echo "5. Démarrer le streaming"
echo "6. Vérifier la qualité audio"
echo "7. Tester avec différents formats"

echo
echo "9. Diagnostic avancé..."

echo "Si le problème persiste:"
echo "- Vérifier les logs système"
echo "- Tester avec un autre périphérique audio"
echo "- Vérifier les permissions audio"
echo "- Redémarrer les services audio"
echo "- Tester avec une version précédente de BUTT"

echo
echo "=== FIN DU DIAGNOSTIC ===" 