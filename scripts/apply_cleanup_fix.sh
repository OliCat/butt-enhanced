#!/bin/bash

# 🛠️ Application du Fix Cleanup BUTT AES67
# =========================================

echo "🛠️ Application du Fix Cleanup BUTT AES67"
echo "========================================="
echo ""

# Configuration
PATCH_FILE="fix_aes67_cleanup.patch"
SOURCE_DIR="src"
BACKUP_DIR="backup_$(date +%Y%m%d_%H%M%S)"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Vérifier que nous sommes dans le bon répertoire
if [ ! -f "configure" ] || [ ! -d "src" ]; then
    log_error "Ce script doit être exécuté depuis le répertoire butt-enhanced"
    exit 1
fi

# Vérifier que le patch existe
if [ ! -f "$PATCH_FILE" ]; then
    log_error "Patch file $PATCH_FILE non trouvé"
    exit 1
fi

log_info "Vérification de l'état actuel..."

# Vérifier s'il y a des processus BUTT actifs
BUTT_PROCESSES=$(pgrep -f "butt" 2>/dev/null | wc -l)
if [ $BUTT_PROCESSES -gt 0 ]; then
    log_warning "$BUTT_PROCESSES processus BUTT actifs détectés"
    echo "   Processus: $(pgrep -f "butt" | tr '\n' ' ')"
    echo ""
    read -p "Arrêter BUTT avant d'appliquer le patch? (y/n): " STOP_BUTT
    
    if [ "$STOP_BUTT" = "y" ]; then
        log_info "Arrêt des processus BUTT..."
        pkill -f "butt" 2>/dev/null
        sleep 3
        
        # Vérifier qu'ils sont bien arrêtés
        REMAINING=$(pgrep -f "butt" 2>/dev/null | wc -l)
        if [ $REMAINING -gt 0 ]; then
            log_warning "$REMAINING processus persistent, force kill..."
            pkill -9 -f "butt" 2>/dev/null
            sleep 2
        fi
        
        log_success "Processus BUTT arrêtés"
    fi
fi

# Créer une sauvegarde
log_info "Création de la sauvegarde..."
mkdir -p "$BACKUP_DIR"

# Sauvegarder les fichiers modifiés
FILES_TO_BACKUP=(
    "src/FLTK/fl_callbacks.cpp"
    "src/port_audio.cpp"
    "src/aes67_output.cpp"
    "src/aes67_ptp.cpp"
    "src/aes67_sap.cpp"
)

for file in "${FILES_TO_BACKUP[@]}"; do
    if [ -f "$file" ]; then
        cp "$file" "$BACKUP_DIR/"
        log_info "Sauvegardé: $file"
    else
        log_warning "Fichier non trouvé: $file"
    fi
done

log_success "Sauvegarde créée dans $BACKUP_DIR"

# Appliquer le patch
log_info "Application du patch..."
if patch -p1 < "$PATCH_FILE"; then
    log_success "Patch appliqué avec succès"
else
    log_error "Échec de l'application du patch"
    echo ""
    log_info "Restoration de la sauvegarde..."
    for file in "${FILES_TO_BACKUP[@]}"; do
        if [ -f "$BACKUP_DIR/$(basename $file)" ]; then
            cp "$BACKUP_DIR/$(basename $file)" "$file"
            log_info "Restauré: $file"
        fi
    done
    exit 1
fi

# Vérifier les modifications
log_info "Vérification des modifications..."

MODIFIED_FILES=0
for file in "${FILES_TO_BACKUP[@]}"; do
    if [ -f "$file" ]; then
        if git diff --quiet "$file" 2>/dev/null; then
            log_warning "Pas de modifications détectées dans $file"
        else
            log_success "Modifications détectées dans $file"
            MODIFIED_FILES=$((MODIFIED_FILES + 1))
        fi
    fi
done

if [ $MODIFIED_FILES -eq 0 ]; then
    log_warning "Aucune modification détectée - vérifier manuellement"
fi

# Recompiler BUTT
log_info "Recompilation de BUTT..."

# Nettoyer les objets précédents
make clean 2>/dev/null

# Compiler
if make -j$(nproc 2>/dev/null || echo 4); then
    log_success "Compilation réussie"
else
    log_error "Échec de la compilation"
    echo ""
    log_info "Restoration de la sauvegarde..."
    for file in "${FILES_TO_BACKUP[@]}"; do
        if [ -f "$BACKUP_DIR/$(basename $file)" ]; then
            cp "$BACKUP_DIR/$(basename $file)" "$file"
            log_info "Restauré: $file"
        fi
    done
    exit 1
fi

# Tester le nouveau binaire
log_info "Test du nouveau binaire..."

if [ -f "./src/butt" ]; then
    # Vérifier que le binaire fonctionne
    if ./src/butt --help >/dev/null 2>&1; then
        log_success "Binaire fonctionnel"
    else
        log_warning "Binaire créé mais test d'aide échoué"
    fi
    
    # Vérifier la taille
    BINARY_SIZE=$(stat -f%z "./src/butt" 2>/dev/null || stat -c%s "./src/butt" 2>/dev/null)
    log_info "Taille du binaire: $BINARY_SIZE bytes"
else
    log_error "Binaire non trouvé après compilation"
    exit 1
fi

# Créer un script de test
log_info "Création du script de test..."

cat > test_cleanup_fix.sh << 'EOF'
#!/bin/bash

# 🧪 Test du Fix Cleanup BUTT
# ===========================

echo "🧪 Test du Fix Cleanup BUTT"
echo "==========================="
echo ""

# Configuration
TEST_DURATION=30  # secondes
LOG_FILE="/tmp/butt_cleanup_test.log"

# Fonctions de logging
log_info() {
    echo -e "\033[0;34m[INFO]\033[0m $1"
}

log_success() {
    echo -e "\033[0;32m[SUCCESS]\033[0m $1"
}

log_warning() {
    echo -e "\033[1;33m[WARNING]\033[0m $1"
}

log_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
}

# Nettoyer les processus existants
log_info "Nettoyage initial..."
pkill -f "butt" 2>/dev/null
sleep 2

# Démarrer BUTT
log_info "Démarrage de BUTT..."
cd /Users/ogrieco/stereoTool_testSDK/butt-enhanced
nohup ./src/butt > "$LOG_FILE" 2>&1 &
BUTT_PID=$!

log_info "BUTT démarré avec PID: $BUTT_PID"

# Attendre que BUTT soit stable
sleep 5

# Vérifier que BUTT fonctionne
if ! ps -p $BUTT_PID >/dev/null 2>&1; then
    log_error "BUTT s'est arrêté prématurément"
    echo "Logs:"
    tail -20 "$LOG_FILE"
    exit 1
fi

log_success "BUTT stable"

# Simuler une session de travail
log_info "Simulation d'une session de travail ($TEST_DURATION secondes)..."

# Monitorer pendant la session
for i in $(seq 1 $TEST_DURATION); do
    if ! ps -p $BUTT_PID >/dev/null 2>&1; then
        log_error "BUTT s'est arrêté pendant le test"
        break
    fi
    
    # Afficher le progrès
    if [ $((i % 10)) -eq 0 ]; then
        echo "   Progrès: $i/$TEST_DURATION secondes"
    fi
    
    sleep 1
done

# Fermer BUTT proprement
log_info "Fermeture propre de BUTT..."

# Simuler la fermeture via interface (envoi signal SIGTERM)
kill -TERM $BUTT_PID

# Attendre la fermeture
TIMEOUT=10
count=0
while [ $count -lt $TIMEOUT ]; do
    if ! ps -p $BUTT_PID >/dev/null 2>&1; then
        log_success "BUTT fermé proprement"
        break
    fi
    sleep 1
    count=$((count + 1))
done

if [ $count -eq $TIMEOUT ]; then
    log_warning "Timeout fermeture, force kill"
    kill -KILL $BUTT_PID 2>/dev/null
    sleep 2
fi

# Vérifier l'état final
log_info "Vérification de l'état final..."

REMAINING_BUTT=$(pgrep -f "butt" 2>/dev/null | wc -l)
REMAINING_AES67=$(lsof -i :5004 2>/dev/null | wc -l)
REMAINING_SAP=$(lsof -i :9875 2>/dev/null | wc -l)

echo "   Processus BUTT restants: $REMAINING_BUTT"
echo "   Connexions AES67 restantes: $REMAINING_AES67"
echo "   Connexions SAP restantes: $REMAINING_SAP"

if [ $REMAINING_BUTT -eq 0 ] && [ $REMAINING_AES67 -eq 0 ] && [ $REMAINING_SAP -eq 0 ]; then
    log_success "✅ Test réussi - Cleanup complet"
    echo ""
    echo "📋 Logs de fermeture:"
    tail -20 "$LOG_FILE" | grep -E "(BUTT:|AES67:|PTP:|SAP:)" || echo "   Aucun log de fermeture trouvé"
else
    log_warning "⚠️ Test partiel - Ressources restantes"
    if [ $REMAINING_BUTT -gt 0 ]; then
        echo "   Processus BUTT persistants: $(pgrep -f "butt" | tr '\n' ' ')"
    fi
fi

echo ""
log_info "Test terminé"
EOF

chmod +x test_cleanup_fix.sh

log_success "Script de test créé: test_cleanup_fix.sh"

# Instructions finales
echo ""
echo "🎯 Fix appliqué avec succès !"
echo "=============================="
echo ""
echo "📋 Actions effectuées:"
echo "   ✅ Sauvegarde créée dans $BACKUP_DIR"
echo "   ✅ Patch appliqué"
echo "   ✅ Code recompilé"
echo "   ✅ Binaire testé"
echo "   ✅ Script de test créé"
echo ""
echo "🧪 Pour tester le fix:"
echo "   ./test_cleanup_fix.sh"
echo ""
echo "🔄 Pour restaurer si nécessaire:"
echo "   cp $BACKUP_DIR/* src/"
echo "   make clean && make"
echo ""
echo "📊 Pour monitorer:"
echo "   watch 'ps aux | grep butt'"
echo "   tail -f /tmp/butt_cleanup_test.log"
echo ""
echo "💡 Le fix apporte:"
echo "   • Arrêt propre AES67 avant autres ressources"
echo "   • Timeout sur les threads PTP/SAP"
echo "   • Logs détaillés du processus de fermeture"
echo "   • Vérification des états avant exit()"
echo ""
log_success "Fix prêt pour test en production !" 