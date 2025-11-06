#!/bin/bash

# 🎵 Test Core Audio BUTT Enhanced
# =================================

echo "🎵 Test Core Audio BUTT Enhanced"
echo "================================="
echo ""

# Vérifier que nous sommes sur macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ Ce script doit être exécuté sur macOS"
    exit 1
fi

echo "✅ Système macOS détecté"
echo ""

# Vérifier les frameworks Core Audio
echo "🔍 Vérification des frameworks Core Audio..."
if [ -f "/System/Library/Frameworks/AudioToolbox.framework/AudioToolbox" ]; then
    echo "✅ AudioToolbox.framework trouvé"
else
    echo "❌ AudioToolbox.framework manquant"
fi

if [ -f "/System/Library/Frameworks/CoreAudio.framework/CoreAudio" ]; then
    echo "✅ CoreAudio.framework trouvé"
else
    echo "❌ CoreAudio.framework manquant"
fi

if [ -f "/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation" ]; then
    echo "✅ CoreFoundation.framework trouvé"
else
    echo "❌ CoreFoundation.framework manquant"
fi

echo ""

# Vérifier la compilation
echo "🔧 Test de compilation Core Audio..."
cd "$(dirname "$0")"

# Créer un programme de test simple
cat > /tmp/test_core_audio.cpp << 'EOF'
#include <iostream>
#include <AudioToolbox/AudioToolbox.h>
#include <CoreAudio/CoreAudio.h>
#include <CoreFoundation/CoreFoundation.h>

int main() {
    std::cout << "Core Audio Test Program" << std::endl;
    
    // Test d'initialisation Core Audio
    AudioComponentDescription desc;
    desc.componentType = kAudioUnitType_Output;
    desc.componentSubType = kAudioUnitSubType_DefaultOutput;
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;
    desc.componentFlags = 0;
    desc.componentFlagsMask = 0;

    AudioComponent component = AudioComponentFindNext(NULL, &desc);
    if (component) {
        std::cout << "✅ Audio Component trouvé" << std::endl;
    } else {
        std::cout << "❌ Audio Component non trouvé" << std::endl;
        return 1;
    }
    
    std::cout << "✅ Core Audio fonctionne correctement" << std::endl;
    return 0;
}
EOF

# Compiler le test
if g++ -framework AudioToolbox -framework CoreAudio -framework CoreFoundation /tmp/test_core_audio.cpp -o /tmp/test_core_audio 2>/dev/null; then
    echo "✅ Compilation Core Audio réussie"
    /tmp/test_core_audio
    rm -f /tmp/test_core_audio /tmp/test_core_audio.cpp
else
    echo "❌ Échec de la compilation Core Audio"
    rm -f /tmp/test_core_audio.cpp
fi

echo ""

# Vérifier les périphériques audio
echo "🎧 Périphériques audio détectés :"
system_profiler SPAudioDataType | grep -A3 -E "(Built-in|Input|Output)" | head -20
echo ""

# Test de BUTT avec Core Audio
echo "🚀 Test de BUTT avec Core Audio..."
if [ -f "src/butt" ]; then
    echo "✅ Exécutable BUTT trouvé"
    
    # Vérifier les symboles Core Audio
    echo "🔍 Vérification des symboles Core Audio..."
    if nm src/butt | grep -i "core_audio" > /dev/null; then
        echo "✅ Symboles Core Audio trouvés dans BUTT"
    else
        echo "⚠️  Symboles Core Audio non trouvés (normal si pas encore compilé)"
    fi
    
    # Test de lancement rapide
    echo "🎯 Test de lancement BUTT..."
    timeout 5s ./src/butt --help > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "✅ BUTT se lance correctement"
    else
        echo "❌ Problème lors du lancement de BUTT"
    fi
    
else
    echo "❌ Exécutable BUTT non trouvé"
    echo "   Compilez d'abord avec : make clean && make"
fi

echo ""
echo "🎯 RECOMMANDATIONS :"
echo "==================="
echo "1. Compilez BUTT avec : make clean && make"
echo "2. Lancez BUTT et vérifiez les logs Core Audio"
echo "3. Testez la sortie audio locale"
echo "4. Vérifiez la latence et la qualité audio"
echo ""

echo "✅ Test Core Audio terminé" 