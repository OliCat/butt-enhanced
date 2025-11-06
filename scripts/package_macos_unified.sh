#!/usr/bin/env bash
set -euo pipefail

# Script unifié de packaging macOS (ARM64 et x86_64)
# - Crée un bundle macOS standard: build/BUTT.app
# - Copie l'exécutable existant (déjà compilé) et les libs Stereo Tool
# - Corrige les dépendances (install_name_tool)
# - Peut créer un DMG
#
# Usage:
#   scripts/package_macos_unified.sh bundle [ARCH=arm64|x86_64] [BINARY_PATH=path]
#   scripts/package_macos_unified.sh dmg    [ARCH=arm64|x86_64]
#   scripts/package_macos_unified.sh all    [ARCH=arm64|x86_64]
#
# Variables d'environnement:
#   ARCH         Architecture cible attendue dans l'exécutable (auto si non défini)
#   BINARY_PATH  Chemin vers l'exécutable à empaqueter (défaut: src/butt)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_DIR}"

APP_NAME="BUTT"
BUNDLE_NAME="${APP_NAME}.app"
BUILD_DIR="${PROJECT_DIR}/build"
BUNDLE_DIR="${BUILD_DIR}/${BUNDLE_NAME}"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
FRAMEWORKS_DIR="${CONTENTS_DIR}/Frameworks"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

ACTION="${1:-bundle}"
ARCH="${ARCH:-}"
BINARY_PATH="${BINARY_PATH:-}"

log() { echo -e "$*"; }
err() { echo "❌ $*" >&2; exit 1; }

detect_arch_from_binary() {
  local bin="$1"
  local file_out
  file_out=$(file "$bin" || true)
  if echo "$file_out" | grep -q "x86_64"; then echo x86_64; return; fi
  if echo "$file_out" | grep -qi "arm64"; then echo arm64; return; fi
  echo "unknown"
}

ensure_executable() {
  if [[ -n "${BINARY_PATH}" && -f "${BINARY_PATH}" ]]; then
    echo "${BINARY_PATH}"
    return 0;
  fi
  if [[ -f "src/butt" ]]; then
    echo "src/butt"
    return 0
  fi
  err "Exécutable introuvable. Fournissez BINARY_PATH=... ou compilez d'abord (ex: make)."
}

pick_stereotool_lib() {
  # Priorité: 9.92 stable, puis 10.51, puis lib locale
  local candidates=(
    "../libStereoTool_992/libStereoTool64.dylib"
    "../libStereoTool_1051/lib/macOS/Universal/64/libStereoTool_64.dylib"
    "libStereoTool64.dylib"
    "${PROJECT_DIR}/butt-1.45.0/libStereoTool64.dylib"
  )
  for p in "${candidates[@]}"; do
    if [[ -f "$p" ]]; then echo "$p"; return 0; fi
  done
  # Recherche globale (fallback lent mais utile)
  local found
  found=$(find "${PROJECT_DIR}" -type f -name "libStereoTool*64*.dylib" -maxdepth 4 2>/dev/null | head -1 || true)
  if [[ -n "$found" ]]; then echo "$found"; return 0; fi
  return 1
}

create_structure() {
  rm -rf "${BUNDLE_DIR}"
  mkdir -p "${MACOS_DIR}" "${FRAMEWORKS_DIR}" "${RESOURCES_DIR}"
}

create_info_plist() {
  local version="1.45.0"
  cat > "${CONTENTS_DIR}/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>${APP_NAME}</string>
  <key>CFBundleIconFile</key><string>butt.icns</string>
  <key>CFBundleIdentifier</key><string>de.danielnoethen.butt</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>${APP_NAME}</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${version}</string>
  <key>CFBundleVersion</key><string>${version}</string>
  <key>LSMinimumSystemVersion</key><string>10.12</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSMicrophoneUsageDescription</key>
  <string>BUTT nécessite l'accès au microphone pour diffuser de l'audio en direct.</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.music</string>
  <key>LSArchitecturePriority</key>
  <array>
    <string>${ARCH}</string>
  </array>
</dict>
</plist>
EOF
}

copy_resources() {
  if [[ -f "icons/butt.icns" ]]; then cp "icons/butt.icns" "${RESOURCES_DIR}/"; fi
  [[ -f "README" ]] && cp "README" "${RESOURCES_DIR}/README.txt"
  [[ -f "ChangeLog" ]] && cp "ChangeLog" "${RESOURCES_DIR}/ChangeLog.txt"
  [[ -f "COPYING" ]] && cp "COPYING" "${RESOURCES_DIR}/LICENSE.txt"
}

fix_deps() {
  local bin_path="$1"
  # ID de la lib vendue
  if [[ -f "${FRAMEWORKS_DIR}/libStereoTool64.dylib" ]]; then
    install_name_tool -id "@executable_path/../Frameworks/libStereoTool64.dylib" \
      "${FRAMEWORKS_DIR}/libStereoTool64.dylib" || true
  fi
  # Remplace la dépendance dans l'exécutable
  otool -L "${bin_path}" | grep -E "libStereoTool.*\\.dylib" | awk '{print $1}' | while read -r dep; do
    [[ -z "${dep}" ]] && continue
    install_name_tool -change "${dep}" "@executable_path/../Frameworks/libStereoTool64.dylib" "${bin_path}" || true
  done
}

bundle() {
  log "🎯 Création du bundle macOS unifié..."

  local exe
  exe=$(ensure_executable)

  local actual_arch
  actual_arch=$(detect_arch_from_binary "${exe}")
  if [[ -z "${ARCH}" ]]; then ARCH="${actual_arch}"; fi
  if [[ "${ARCH}" != "${actual_arch}" ]]; then
    log "⚠️  Avertissement: l'exécutable (${actual_arch}) ne correspond pas à l'ARCH demandée (${ARCH})."
  fi

  create_structure
  create_info_plist

  # Copie exécutable
  cp "${exe}" "${MACOS_DIR}/${APP_NAME}"
  chmod +x "${MACOS_DIR}/${APP_NAME}"

  # Choix et copie lib StereoTool
  local st_lib
  if st_lib=$(pick_stereotool_lib); then
    log "✅ Bibliothèque StereoTool trouvée: ${st_lib}"
    cp "${st_lib}" "${FRAMEWORKS_DIR}/libStereoTool64.dylib"
  else
    log "⚠️  Avertissement: aucune lib StereoTool trouvée. Le bundle peut manquer des fonctionnalités."
  fi

  copy_resources
  fix_deps "${MACOS_DIR}/${APP_NAME}"

  log "✅ Bundle créé: ${BUNDLE_DIR}"
}

create_dmg() {
  local dmg_name="BUTT-${ARCH:-unknown}-macOS-StereoTool.dmg"
  local dmg_path="${BUILD_DIR}/${dmg_name}"
  rm -f "${dmg_path}"
  hdiutil create -srcfolder "${BUNDLE_DIR}" -volname "BUTT-${ARCH}" -format UDZO -imagekey zlib-level=9 "${dmg_path}"
  log "✅ DMG créé: ${dmg_path}"
}

case "${ACTION}" in
  bundle)
    bundle
    ;;
  dmg)
    [[ -d "${BUNDLE_DIR}" ]] || bundle
    create_dmg
    ;;
  all)
    bundle
    create_dmg
    ;;
  *)
    echo "Usage: $0 [bundle|dmg|all] (ARCH=arm64|x86_64) (BINARY_PATH=...)";
    exit 1;
    ;;
esac


