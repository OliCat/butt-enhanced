#!/bin/bash

# Script de nettoyage pour préparer BUTT Enhanced pour GitHub
# Usage: ./CLEANUP_PROJECT.sh

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🧹 Nettoyage du projet BUTT Enhanced pour GitHub${NC}"
echo ""

# Créer un répertoire pour archiver (au cas où)
ARCHIVE_DIR="archives_dev_$(date +%Y%m%d)"
echo -e "${YELLOW}📦 Création de l'archive : $ARCHIVE_DIR${NC}"
mkdir -p "$ARCHIVE_DIR"

# 1. Archiver les fichiers de debug/correction
echo -e "${BLUE}📝 Archivage des fichiers de debug...${NC}"
mv CORRECTION_*.md "$ARCHIVE_DIR/" 2>/dev/null || true
mv DEBUG_*.md "$ARCHIVE_DIR/" 2>/dev/null || true
mv SOLUTION_*.md "$ARCHIVE_DIR/" 2>/dev/null || true
mv GUIDE_TEST_*.md "$ARCHIVE_DIR/" 2>/dev/null || true
mv QUICK_WINS_*.md "$ARCHIVE_DIR/" 2>/dev/null || true
mv SYNTHESE_*.md "$ARCHIVE_DIR/" 2>/dev/null || true
mv CHANGELOG_V0.3.md "$ARCHIVE_DIR/" 2>/dev/null || true

# 2. Archiver les logs et fichiers temporaires
echo -e "${BLUE}🗑️  Archivage des logs et fichiers temporaires...${NC}"
mv *.log "$ARCHIVE_DIR/" 2>/dev/null || true
mv *.tmp "$ARCHIVE_DIR/" 2>/dev/null || true
mv debug_*.* "$ARCHIVE_DIR/" 2>/dev/null || true
mv compile_*.log "$ARCHIVE_DIR/" 2>/dev/null || true

# 3. Archiver les anciens backups
echo -e "${BLUE}💾 Archivage des backups...${NC}"
mv backup_* "$ARCHIVE_DIR/" 2>/dev/null || true

# 4. Archiver les anciens builds
echo -e "${BLUE}🔨 Archivage des anciens builds...${NC}"
mv build-x86_64 "$ARCHIVE_DIR/" 2>/dev/null || true
mv build-arm64 "$ARCHIVE_DIR/" 2>/dev/null || true
mv BUTT-M2-fixed "$ARCHIVE_DIR/" 2>/dev/null || true

# 5. Archiver les fichiers de test
echo -e "${BLUE}🧪 Archivage des fichiers de test...${NC}"
mv test_*.sh "$ARCHIVE_DIR/" 2>/dev/null || true
mv test_*.py "$ARCHIVE_DIR/" 2>/dev/null || true
mv test_*.sdp "$ARCHIVE_DIR/" 2>/dev/null || true
mv test_*.wav "$ARCHIVE_DIR/" 2>/dev/null || true
mv simple_stereo_test "$ARCHIVE_DIR/" 2>/dev/null || true

# 6. Archiver les anciens scripts d'analyse
echo -e "${BLUE}📊 Archivage des scripts d'analyse...${NC}"
mv integration_blackhole_butt.tar.gz "$ARCHIVE_DIR/" 2>/dev/null || true

# 7. Archiver les fichiers de capture réseau
echo -e "${BLUE}🌐 Archivage des captures réseau...${NC}"
mv *.pcap "$ARCHIVE_DIR/" 2>/dev/null || true
mv aes67_*.txt "$ARCHIVE_DIR/" 2>/dev/null || true
mv sap_captures "$ARCHIVE_DIR/" 2>/dev/null || true

# 8. Nettoyer les fichiers de compilation temporaires
echo -e "${BLUE}🔧 Nettoyage des fichiers de compilation...${NC}"
find . -name "*.o" -type f -delete 2>/dev/null || true
find . -name ".deps" -type d -exec rm -rf {} + 2>/dev/null || true

# 9. Compresser l'archive
echo -e "${BLUE}📦 Compression de l'archive...${NC}"
tar -czf "${ARCHIVE_DIR}.tar.gz" "$ARCHIVE_DIR"
rm -rf "$ARCHIVE_DIR"

echo ""
echo -e "${GREEN}✅ Nettoyage terminé !${NC}"
echo ""
echo -e "${YELLOW}📁 Archive créée : ${ARCHIVE_DIR}.tar.gz${NC}"
echo -e "${YELLOW}   Contient tous les fichiers de développement (au cas où)${NC}"
echo ""
echo -e "${GREEN}📋 Fichiers conservés :${NC}"
echo "   ✅ Code source (src/)"
echo "   ✅ Documentation utilisateur"
echo "   ✅ Scripts utiles"
echo "   ✅ Configuration du projet"
echo ""
echo -e "${BLUE}🚀 Prochaine étape : Vérifier les nouveaux fichiers GitHub${NC}"
echo "   - README.md"
echo "   - LICENSE"
echo "   - .gitignore"
echo "   - CONTRIBUTING.md"
echo ""

