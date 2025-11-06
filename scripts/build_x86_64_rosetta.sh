#!/bin/zsh
set -euo pipefail

# Build BUTT-Enhanced (x86_64) depuis un Mac ARM via Rosetta

export PATH=/usr/local/bin:/usr/bin:/bin

# Homebrew Intel PKG_CONFIG_PATH (dépendances en /usr/local/opt)
export PKG_CONFIG_PATH="/usr/local/opt/libogg/lib/pkgconfig:/usr/local/opt/libvorbis/lib/pkgconfig:/usr/local/opt/opus/lib/pkgconfig:/usr/local/opt/flac/lib/pkgconfig:/usr/local/opt/lame/lib/pkgconfig:/usr/local/opt/portaudio/lib/pkgconfig:/usr/local/opt/portmidi/lib/pkgconfig:/usr/local/opt/libsamplerate/lib/pkgconfig:/usr/local/opt/openssl@3/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

# Flags x86_64 + macOS min ver + includes/libs Intel Homebrew
export CFLAGS="-arch x86_64 -mmacosx-version-min=10.12"
export CXXFLAGS="-arch x86_64 -mmacosx-version-min=10.12 -O2"
export LDFLAGS="-arch x86_64 -mmacosx-version-min=10.12 -L/usr/local/lib -Wl,-rpath,/usr/local/lib"
export CPPFLAGS="-I/usr/local/include"

echo "[build] configure (host=x86_64, build=arm64)"
arch -x86_64 zsh -lc "cd $(dirname $0)/.. && ./configure --host=x86_64-apple-darwin --build=arm64-apple-darwin --disable-nls"

echo "[build] make -j$(sysctl -n hw.ncpu)"
arch -x86_64 zsh -lc "cd $(dirname $0)/../src && make -j$(sysctl -n hw.ncpu)"

echo "[build] OK → binaire: butt-enhanced/src/butt (x86_64)"


