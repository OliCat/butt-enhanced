#!/bin/bash

# Script de signature de code et notarisation pour macOS
# Auteur: BUTT Enhanced v0.3
# Version: 1.0

set -e

echo "🔐 Script de signature de code et notarisation BUTT Enhanced"

# Configuration
APP_NAME="BUTT"
BUNDLE_NAME="BUTT.app"
BUNDLE_ID="de.danielnoethen.butt"
DEVELOPER_ID="${DEVELOPER_ID:-Developer ID Application: Your Name (TEAM_ID)}"
NOTARIZATION_PROFILE="${NOTARIZATION_PROFILE:-notarytool-profile}"

# Répertoires (résolus depuis l'emplacement du script)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
# Permettre la surcharge via env BUNDLE_PATH
BUNDLE_PATH="${BUNDLE_PATH:-$BUILD_DIR/$BUNDLE_NAME}"

# Vérifications préalables
if [ ! -d "$BUNDLE_PATH" ]; then
    # Fallback: essayer bundle Intel
    if [ -d "$PROJECT_DIR/build-x86_64/BUTT-Intel.app" ]; then
        echo "ℹ️  Fallback: détection d'un bundle Intel"
        BUNDLE_PATH="$PROJECT_DIR/build-x86_64/BUTT-Intel.app"
    else
        echo "❌ Erreur: Bundle non trouvé à $BUNDLE_PATH"
        echo "Créez d'abord un bundle (ex: scripts/package_macos_unified.sh bundle)"
        exit 1
    fi
fi

# Fonction pour vérifier la disponibilité des outils
check_codesign_requirements() {
    echo "🔍 Vérification des prérequis..."
    
    # Vérifier codesign
    if ! command -v codesign >/dev/null 2>&1; then
        echo "❌ Erreur: codesign non trouvé. Installez Xcode Command Line Tools."
        exit 1
    fi
    
    # Vérifier xcrun notarytool
    if ! xcrun notarytool --help >/dev/null 2>&1; then
        echo "❌ Erreur: notarytool non disponible. Requires Xcode 13+ ou macOS 12+."
        echo "ℹ️  Pour les versions antérieures, utilisez altool au lieu de notarytool."
    fi
    
    echo "✅ Outils disponibles"
}

# Fonction pour créer le fichier entitlements
create_entitlements() {
    local entitlements_file="$BUILD_DIR/entitlements.plist"
    
    echo "📝 Création du fichier entitlements..."
    cat > "$entitlements_file" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Autorisation pour l'accès au microphone -->
    <key>com.apple.security.device.microphone</key>
    <true/>
    
    <!-- Hardened Runtime requis pour notarisation -->
    <key>com.apple.security.cs.allow-jit</key>
    <false/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <false/>
    <key>com.apple.security.cs.allow-dyld-environment-variables</key>
    <false/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <false/>
    
    <!-- Accès réseau pour streaming -->
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <true/>
    
    <!-- Lecture de fichiers audio -->
    <key>com.apple.security.files.user-selected.read-only</key>
    <true/>
</dict>
</plist>
EOF
    
    echo "✅ Entitlements créés: $entitlements_file"
    return 0
}

# Fonction pour signer le code
sign_bundle() {
    local entitlements_file="$BUILD_DIR/entitlements.plist"
    
    echo "🔏 Signature du bundle..."
    
    # Signer les frameworks d'abord
    echo "📚 Signature des frameworks..."
    for framework in "$BUNDLE_PATH/Contents/Frameworks"/*.dylib; do
        if [ -f "$framework" ]; then
            echo "  - $(basename "$framework")"
            codesign --force --sign "$DEVELOPER_ID" \
                     --options runtime \
                     --timestamp \
                     "$framework"
        fi
    done
    
    # Signer l'application principale
    echo "📱 Signature de l'application..."
    codesign --force --sign "$DEVELOPER_ID" \
             --entitlements "$entitlements_file" \
             --options runtime \
             --timestamp \
             "$BUNDLE_PATH"
    
    echo "✅ Signature terminée"
}

# Fonction pour vérifier la signature
verify_signature() {
    echo "🔍 Vérification de la signature..."
    
    # Vérification de base
    codesign --verify --verbose=2 "$BUNDLE_PATH"
    
    # Vérification Gatekeeper
    spctl --assess --type exec --verbose=2 "$BUNDLE_PATH"
    
    echo "✅ Signature vérifiée avec succès"
}

# Fonction pour créer le DMG signé
create_signed_dmg() {
    local dmg_name="BUTT-Enhanced-v0.3-macOS-Signed.dmg"
    local dmg_path="$BUILD_DIR/$dmg_name"
    
    echo "💿 Création du DMG signé..."
    
    # Supprimer l'ancien DMG s'il existe
    [ -f "$dmg_path" ] && rm "$dmg_path"
    
    # Créer le DMG
    hdiutil create -srcfolder "$BUNDLE_PATH" \
                   -volname "BUTT Enhanced v0.3" \
                   -format UDZO \
                   -compression 9 \
                   "$dmg_path"
    
    # Signer le DMG
    echo "🔏 Signature du DMG..."
    codesign --force --sign "$DEVELOPER_ID" \
             --timestamp \
             "$dmg_path"
    
    echo "✅ DMG signé créé: $dmg_path"
}

# Fonction pour notariser (nécessite un profil Apple Developer configuré)
notarize_app() {
    local dmg_name="BUTT-Enhanced-v0.3-macOS-Signed.dmg"
    local dmg_path="$BUILD_DIR/$dmg_name"
    
    echo "📮 Notarisation de l'application..."
    echo "ℹ️  Note: Nécessite un compte Apple Developer et un profil notarytool configuré"
    
    # Vérifier si le profil existe
    if ! xcrun notarytool store-credentials --list | grep -q "$NOTARIZATION_PROFILE"; then
        echo "⚠️  Profil de notarisation '$NOTARIZATION_PROFILE' non trouvé."
        echo "   Configurez-le avec:"
        echo "   xcrun notarytool store-credentials --apple-id your@email.com --team-id TEAM_ID --password app-password"
        return 1
    fi
    
    # Soumettre pour notarisation
    echo "📤 Soumission à Apple..."
    local submit_result
    submit_result=$(xcrun notarytool submit "$dmg_path" \
                               --keychain-profile "$NOTARIZATION_PROFILE" \
                               --wait)
    
    if echo "$submit_result" | grep -q "Successfully received submission"; then
        echo "✅ Notarisation réussie"
        
        # Agrafer le ticket de notarisation
        echo "📎 Agrafage du ticket..."
        xcrun stapler staple "$dmg_path"
        
        # Vérifier l'agrafage
        xcrun stapler validate "$dmg_path"
        
        echo "✅ Application notarisée et agrafée avec succès"
    else
        echo "❌ Échec de la notarisation"
        echo "$submit_result"
        return 1
    fi
}

# Menu principal
show_usage() {
    echo "Usage: $0 [option]"
    echo ""
    echo "Options:"
    echo "  sign        Signer le bundle uniquement"
    echo "  verify      Vérifier la signature existante"
    echo "  dmg         Créer un DMG signé"
    echo "  notarize    Notariser l'application (nécessite un profil Apple Developer)"
    echo "  all         Processus complet: sign + dmg + notarize"
    echo "  help        Afficher cette aide"
    echo ""
    echo "Variables d'environnement:"
    echo "  DEVELOPER_ID              Identité de signature (ex: 'Developer ID Application: Name (TEAM_ID)')"
    echo "  NOTARIZATION_PROFILE      Profil notarytool (défaut: 'notarytool-profile')"
    echo ""
    echo "Exemple:"
    echo "  export DEVELOPER_ID='Developer ID Application: My Company (ABC123)'"
    echo "  $0 all"
}

# Fonction principale
main() {
    local action="${1:-help}"
    
    case "$action" in
        "sign")
            check_codesign_requirements
            create_entitlements
            sign_bundle
            ;;
        "verify")
            verify_signature
            ;;
        "dmg")
            create_signed_dmg
            ;;
        "notarize")
            notarize_app
            ;;
        "all")
            check_codesign_requirements
            create_entitlements
            sign_bundle
            verify_signature
            create_signed_dmg
            echo ""
            echo "🎉 Processus de signature terminé!"
            echo "📦 Résultats:"
            echo "   - Bundle signé: $BUNDLE_PATH"
            echo "   - DMG signé: $BUILD_DIR/BUTT-Enhanced-v0.3-macOS-Signed.dmg"
            echo ""
            echo "💡 Pour notariser (optionnel):"
            echo "   1. Configurez un profil notarytool"
            echo "   2. Lancez: $0 notarize"
            ;;
        "help"|*)
            show_usage
            ;;
    esac
}

# Point d'entrée
main "$@"
