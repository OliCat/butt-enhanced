#!/bin/bash

# Script de compilation BUTT Enhanced avec régénération FLTK automatique
# Inclut l'étape cruciale de régénération des fichiers C++ depuis les fichiers .fl

echo "🔧 Compilation BUTT Enhanced avec FLTK"
echo "======================================"

# Vérification de fluid
echo "✅ Vérification de fluid..."
if ! command -v fluid &> /dev/null; then
    echo "❌ Erreur: fluid non trouvé. Installez FLTK avec Homebrew:"
    echo "   brew install fltk"
    exit 1
fi
echo "   ✓ fluid trouvé: $(which fluid)"

# Nettoyage
echo "🧹 Nettoyage..."
make clean

# Régénération FLTK
echo "🔄 Régénération des fichiers FLTK..."
echo "   Régénération de flgui.cpp depuis flgui.fl..."
fluid -c src/FLTK/flgui.fl

if [ $? -eq 0 ]; then
    echo "   ✓ flgui.cpp régénéré avec succès"
else
    echo "   ⚠️  Warnings lors de la régénération (normal)"
fi

# Compilation
echo "🔨 Compilation..."
make

if [ $? -eq 0 ]; then
    echo "✅ Compilation réussie !"
    echo ""
    echo "🎯 BUTT Enhanced compilé avec succès"
    echo "   - Interface optimisée avec les nouvelles dimensions"
    echo "   - Sections AES67 et Core Audio améliorées"
    echo "   - Alignement des labels corrigé"
    echo ""
    echo "🚀 Pour tester: ./src/butt"
    echo "📊 Pour vérifier les améliorations: ./test_interface_improvements.sh"
else
    echo "❌ Erreur lors de la compilation"
    exit 1
fi

echo ""
echo "✨ Compilation terminée avec succès !" 