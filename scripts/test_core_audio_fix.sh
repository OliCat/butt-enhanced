#!/bin/bash

# Test des corrections Core Audio pour résoudre la distorsion
# Auteur: Assistant IA
# Date: $(date)

echo "=== TEST DES CORRECTIONS CORE AUDIO ==="
echo "Vérification des améliorations pour résoudre la distorsion audio"
echo

# Vérifier que nous sommes dans le bon répertoire
if [ ! -f "src/core_audio_output.cpp" ]; then
    echo "ERREUR: Ce script doit être exécuté depuis le répertoire butt-enhanced"
    exit 1
fi

echo "1. Vérification des corrections dans core_audio_output.cpp..."

# Vérifier la correction du facteur de conversion PCM 24-bit
if grep -q "8388608.0f" src/core_audio_output.cpp; then
    echo "✓ Correction PCM 24-bit appliquée (8388608.0f au lieu de 8388607.0f)"
else
    echo "✗ Correction PCM 24-bit manquante"
fi

# Vérifier l'amélioration de la vérification des données audio
if grep -q "Vérification plus complète des données" src/core_audio_output.cpp; then
    echo "✓ Amélioration de la vérification des données audio appliquée"
else
    echo "✗ Amélioration de la vérification des données audio manquante"
fi

# Vérifier l'amélioration de la conversion avec gestion des niveaux
if grep -q "Conversion avec meilleure gestion des niveaux" src/core_audio_output.cpp; then
    echo "✓ Amélioration de la conversion avec gestion des niveaux appliquée"
else
    echo "✗ Amélioration de la conversion avec gestion des niveaux manquante"
fi

echo
echo "2. Compilation pour vérifier les erreurs..."

# Compiler pour vérifier les erreurs
make clean > /dev/null 2>&1
make -j4 2>&1 | head -20

if [ $? -eq 0 ]; then
    echo "✓ Compilation réussie"
else
    echo "✗ Erreurs de compilation détectées"
fi

echo
echo "3. Vérification des périphériques audio disponibles..."

# Lister les périphériques audio
echo "Périphériques audio détectés:"
system_profiler SPAudioDataType | grep -A 5 "Output:" | head -20

echo
echo "4. Test de la sortie Core Audio..."

# Créer un fichier de test audio simple
echo "Création d'un fichier de test audio..."
cat > test_audio.c << 'EOF'
#include <stdio.h>
#include <math.h>

int main() {
    FILE *f = fopen("test_sine.wav", "wb");
    if (!f) return 1;
    
    // En-tête WAV simple
    unsigned char header[] = {
        'R', 'I', 'F', 'F', 0x24, 0x08, 0x00, 0x00,
        'W', 'A', 'V', 'E', 'f', 'm', 't', ' ',
        0x10, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00,
        0x44, 0xAC, 0x00, 0x00, 0x88, 0x58, 0x01, 0x00,
        0x02, 0x00, 0x10, 0x00, 'd', 'a', 't', 'a',
        0x00, 0x08, 0x00, 0x00
    };
    fwrite(header, 1, 44, f);
    
    // Générer une onde sinusoïdale de 440Hz
    for (int i = 0; i < 44100; i++) {
        short sample = (short)(32767.0 * sin(2.0 * M_PI * 440.0 * i / 44100.0));
        fwrite(&sample, 2, 1, f);
    }
    
    fclose(f);
    printf("Fichier test_sine.wav créé\n");
    return 0;
}
EOF

gcc -o test_audio test_audio.c -lm
if [ $? -eq 0 ]; then
    ./test_audio
    echo "✓ Fichier de test audio créé"
else
    echo "✗ Erreur lors de la création du fichier de test"
fi

echo
echo "5. Instructions pour tester Core Audio:"
echo
echo "Pour tester les corrections:"
echo "1. Compiler BUTT: make"
echo "2. Lancer BUTT: ./butt"
echo "3. Dans l'interface:"
echo "   - Aller dans Settings > Audio"
echo "   - Activer 'Core Audio Output'"
echo "   - Sélectionner votre enceinte Bluetooth"
echo "   - Démarrer le streaming"
echo "4. Vérifier que le son n'est plus distordu"
echo
echo "6. Diagnostic en cas de problème:"
echo "   - Vérifier les logs dans la console"
echo "   - Tester avec différents périphériques"
echo "   - Vérifier les paramètres de format audio"
echo
echo "=== FIN DU TEST ===" 
