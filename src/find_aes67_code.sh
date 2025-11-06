#!/bin/bash
# Script pour trouver le code AES67

echo "=== Recherche du code AES67 ==="
echo ""

# Rechercher les références à AES67
echo "1. Recherche des références à AES67:"
echo ""
grep -r "aes67\|AES67" ~/ 2>/dev/null | grep -v ".git\|node_modules\|Library\|.Trash" | head -20
echo ""

# Rechercher les références à l'adresse multicast
echo "2. Recherche des références à 239.69.145.58:"
echo ""
grep -r "239.69.145.58" ~/ 2>/dev/null | grep -v ".git\|node_modules\|Library\|.Trash" | head -20
echo ""

# Rechercher les références au port 5004
echo "3. Recherche des références au port 5004:"
echo ""
grep -r "5004" ~/ 2>/dev/null | grep -v ".git\|node_modules\|Library\|.Trash" | head -20
echo ""

# Rechercher les références à Stéréotool
echo "4. Recherche des références à Stéréotool:"
echo ""
grep -r "stereotool\|Stereotool" ~/ 2>/dev/null | grep -v ".git\|node_modules\|Library\|.Trash" | head -20
echo ""

# Rechercher les références à BUTT
echo "5. Recherche des références à BUTT:"
echo ""
grep -r "butt\|BUTT" ~/ 2>/dev/null | grep -v ".git\|node_modules\|Library\|.Trash" | head -20
echo ""

echo "=== Instructions ==="
echo ""
echo "Si vous trouvez des fichiers pertinents, notez leur emplacement"
echo "et le langage utilisé (C/C++, Python, Objective-C, etc.)"
echo ""
echo "Vous pouvez aussi chercher dans des répertoires spécifiques:"
echo "  - /Applications/"
echo "  - ~/Documents/"
echo "  - ~/Projects/"
echo "  - ~/Code/"
