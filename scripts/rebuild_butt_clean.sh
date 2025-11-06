#!/usr/bin/env bash
set -euo pipefail

# Script pour recompiler BUTT sans conflits FLTK
# Résout le problème des classes FLTK dupliquées

echo "🔧 Recompilation de BUTT sans conflits FLTK"
echo "============================================="
echo

# 1. Nettoyer le build précédent
echo "1. Nettoyage du build précédent..."
make clean 2>/dev/null || true
rm -f src/butt
echo "✅ Nettoyage terminé"
echo

# 2. Vérifier les dépendances FLTK
echo "2. Vérification des dépendances FLTK..."
if ! pkg-config --exists fltk; then
    echo "❌ FLTK non trouvé via pkg-config"
    echo "   Installation recommandée: brew install fltk"
    exit 1
fi

FLTK_CFLAGS=$(pkg-config --cflags fltk)
FLTK_LIBS=$(pkg-config --libs fltk)

echo "   FLTK CFLAGS: $FLTK_CFLAGS"
echo "   FLTK LIBS: $FLTK_LIBS"
echo "✅ FLTK détecté"
echo

# 3. Reconfigurer avec les bonnes options
echo "3. Reconfiguration du projet..."
./configure \
    --enable-shared \
    --disable-static \
    CFLAGS="-O2 -g -Wall $FLTK_CFLAGS" \
    CXXFLAGS="-O2 -g -Wall $FLTK_CFLAGS" \
    LDFLAGS="$FLTK_LIBS" \
    LIBS="$FLTK_LIBS"
echo "✅ Configuration terminée"
echo

# 4. Compiler avec les bonnes options
echo "4. Compilation..."
make -j$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
echo "✅ Compilation terminée"
echo

# 5. Vérifier le binaire
echo "5. Vérification du binaire..."
if [[ -f "src/butt" ]]; then
    echo "✅ Binaire créé: src/butt"
    echo "   Taille: $(ls -lh src/butt | awk '{print $5}')"
    echo "   Architecture: $(lipo -info src/butt 2>/dev/null || file src/butt)"
    
    # Vérifier les dépendances FLTK
    echo "   Dépendances FLTK:"
    otool -L src/butt | grep fltk || echo "     Aucune dépendance FLTK directe"
else
    echo "❌ Binaire non créé"
    exit 1
fi
echo

# 6. Test de lancement
echo "6. Test de lancement..."
echo "   Test avec --version..."
if src/butt --version >/dev/null 2>&1; then
    echo "✅ Lancement en ligne de commande OK"
else
    echo "❌ Erreur de lancement en ligne de commande"
    exit 1
fi
echo

echo "🎯 Recompilation terminée avec succès !"
echo "   Le binaire src/butt est prêt pour le bundle"
echo
echo "Prochaines étapes:"
echo "1. ./scripts/build_universal_dmg.sh --arch x86_64"
echo "2. Tester le bundle avec open build/BUTT.app"
