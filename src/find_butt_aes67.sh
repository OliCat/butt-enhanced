#!/bin/bash
# Script pour trouver le code AES67 dans BUTT

echo "=== Recherche du code AES67 dans BUTT ==="
echo ""

# Rechercher les répertoires BUTT
echo "1. Recherche des répertoires BUTT:"
echo ""
find ~ -type d -iname "*butt*" 2>/dev/null | grep -v ".git\|node_modules\|Library\|.Trash" | head -10
echo ""

# Rechercher les fichiers C++ liés à AES67
echo "2. Recherche des fichiers C++ liés à AES67:"
echo ""
find ~ -type f \( -name "*.cpp" -o -name "*.cxx" -o -name "*.cc" -o -name "*.h" -o -name "*.hpp" \) 2>/dev/null | \
    xargs grep -l "aes67\|AES67\|239.69.145.58\|5004" 2>/dev/null | \
    grep -v ".git\|node_modules\|Library\|.Trash" | head -20
echo ""

# Rechercher les références à multicast/UDP
echo "3. Recherche des références à multicast/UDP:"
echo ""
find ~ -type f \( -name "*.cpp" -o -name "*.h" \) 2>/dev/null | \
    xargs grep -l "multicast\|udp\|UDP\|rtp\|RTP" 2>/dev/null | \
    grep -v ".git\|node_modules\|Library\|.Trash" | head -20
echo ""

# Rechercher les références à Stéréotool
echo "4. Recherche des références à Stéréotool:"
echo ""
find ~ -type f \( -name "*.cpp" -o -name "*.h" \) 2>/dev/null | \
    xargs grep -l "stereotool\|Stereotool" 2>/dev/null | \
    grep -v ".git\|node_modules\|Library\|.Trash" | head -20
echo ""

echo "=== Instructions ==="
echo ""
echo "Notez les fichiers trouvés, en particulier ceux qui contiennent:"
echo "  - AES67"
echo "  - 239.69.145.58"
echo "  - 5004"
echo "  - multicast/UDP"
echo ""
echo "Ces fichiers contiennent probablement le code AES67."
