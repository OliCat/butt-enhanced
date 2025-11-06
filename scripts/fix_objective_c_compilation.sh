#!/bin/bash

# Script pour corriger la compilation Objective-C
# Changement de -x objective-c++ vers -x objective-c pour éviter le name mangling

set -e

echo "🔧 Correction de la compilation Objective-C..."
echo "============================================="
echo ""

# Sauvegarde des Makefiles originaux
echo "📋 Sauvegarde des Makefiles..."
if [ ! -f "Makefile.backup" ]; then
    cp Makefile Makefile.backup
    echo "✅ Sauvegarde Makefile → Makefile.backup"
fi

if [ ! -f "src/Makefile.backup" ]; then
    cp src/Makefile src/Makefile.backup  
    echo "✅ Sauvegarde src/Makefile → src/Makefile.backup"
fi

echo ""
echo "🔨 Application des corrections..."

# Correction du Makefile principal
sed -i.temp 's/-x objective-c++/-x objective-c/g' Makefile
echo "✅ Makefile principal corrigé"

# Correction du Makefile src
sed -i.temp 's/-x objective-c++/-x objective-c/g' src/Makefile
echo "✅ src/Makefile corrigé"

# Nettoyage des fichiers temporaires
rm -f Makefile.temp src/Makefile.temp

echo ""
echo "🧹 Nettoyage et recompilation des fichiers Objective-C..."

# Nettoyage des objets .m qui ont été mal compilés
cd src
rm -f CurrentTrackOSX.o AskForMicPermission.o
echo "✅ Fichiers objets .m supprimés"

# Recompilation spécifique des fichiers .m avec les bons flags
echo ""
echo "🔄 Recompilation des fichiers Objective-C..."

# Compilation d'AskForMicPermission.m
echo "   📁 Compilation AskForMicPermission.m..."
clang -arch x86_64 -DHAVE_CONFIG_H -I. -I..  -IFLTK -DLOCALEDIR='"/usr/local/share/locale"' -D_="gettext" -I/usr/local/include -x objective-c -arch x86_64 -mmacosx-version-min=10.12 -MT AskForMicPermission.o -MD -MP -MF .deps/AskForMicPermission.Tpo -c -o AskForMicPermission.o AskForMicPermission.m
mv .deps/AskForMicPermission.Tpo .deps/AskForMicPermission.Po

# Compilation de CurrentTrackOSX.m  
echo "   📁 Compilation CurrentTrackOSX.m..."
clang -arch x86_64 -DHAVE_CONFIG_H -I. -I..  -IFLTK -DLOCALEDIR='"/usr/local/share/locale"' -D_="gettext" -I/usr/local/include -x objective-c -arch x86_64 -mmacosx-version-min=10.12 -MT CurrentTrackOSX.o -MD -MP -MF .deps/CurrentTrackOSX.Tpo -c -o CurrentTrackOSX.o CurrentTrackOSX.m
mv .deps/CurrentTrackOSX.Tpo .deps/CurrentTrackOSX.Po

echo ""
echo "🔍 Vérification des symboles..."

# Vérification que les symboles sont maintenant corrects
echo "Symboles dans AskForMicPermission.o:"
nm AskForMicPermission.o | grep -E "(askForMicPermission|_askForMicPermission)" || echo "❌ Symbole non trouvé"

echo ""
echo "Symboles dans CurrentTrackOSX.o:"  
nm CurrentTrackOSX.o | grep -E "(getCurrentTrackFunctionFromId|_getCurrentTrackFunctionFromId)" || echo "❌ Symbole non trouvé"

cd ..

echo ""
echo "✅ Correction terminée !"
echo ""
echo "📝 Prochaines étapes:"
echo "   make                          # Terminer la compilation"
echo "   make clean && make            # Ou recompilation complète si problème"
echo ""
echo "🔙 Pour restaurer les Makefiles originaux:"
echo "   cp Makefile.backup Makefile"
echo "   cp src/Makefile.backup src/Makefile"