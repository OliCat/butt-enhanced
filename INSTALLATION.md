# 📦 Installation Guide - BUTT Enhanced

Complete installation guide for BUTT Enhanced on macOS.

---

## 📋 Table of Contents

1. [System Requirements](#-system-requirements)
2. [Prerequisites](#-prerequisites)
3. [Installation Methods](#-installation-methods)
4. [StereoTool SDK Setup](#️-stereotool-sdk-setup-optional)
5. [First Launch](#-first-launch)
6. [Configuration](#️-configuration)
7. [Troubleshooting](#-troubleshooting)

---

## 💻 System Requirements

### Minimum
- **OS**: macOS 11.0 (Big Sur) or later
- **CPU**: Apple Silicon (M1/M2/M3) or Intel x86_64
- **RAM**: 4 GB
- **Disk**: 200 MB free space
- **Network**: Ethernet (for AES67)

### Recommended
- **OS**: macOS 13.0 (Ventura) or later
- **CPU**: Apple Silicon M1 or newer
- **RAM**: 8 GB or more
- **Network**: Gigabit Ethernet with multicast support

---

## 📦 Prerequisites

### 1. Install Homebrew (if not already installed)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 2. Install BlackHole Virtual Audio Driver

```bash
brew install blackhole-2ch
```

**Verify installation:**
```bash
# List audio devices
system_profiler SPAudioDataType
```

You should see "BlackHole 2ch" in the output.

---

## 🚀 Installation Methods

### Method 1: Pre-built Bundle (Recommended)

*Coming soon - Release page will have ready-to-use .dmg files*

### Method 2: Build from Source

#### Step 1: Install Build Dependencies

```bash
# Install all required dependencies
brew install \
    portaudio \
    opus \
    flac \
    lame \
    fltk \
    libvorbis \
    libogg \
    libsamplerate \
    portmidi \
    openssl@3 \
    gettext \
    pkg-config \
    autoconf \
    automake \
    libtool
```

#### Step 2: Clone Repository

```bash
# Clone the repository
git clone https://github.com/VOTRE_ORG/butt-enhanced.git
cd butt-enhanced
```

#### Step 3: Download StereoTool SDK (Optional)

See [StereoTool SDK Setup](#️-stereotool-sdk-setup-optional) section below.

#### Step 4: Configure

```bash
# Generate configure script (if not present)
autoreconf -fi

# Configure with proper paths for Apple Silicon
./configure \
    --host=arm64-apple-darwin \
    --build=arm64-apple-darwin \
    --prefix=/opt/homebrew \
    CXX="clang++ -arch arm64" \
    CXXFLAGS="-arch arm64 -mmacosx-version-min=11.0 -O2" \
    LDFLAGS="-L/opt/homebrew/lib -arch arm64" \
    CPPFLAGS="-I/opt/homebrew/include" \
    CC="clang -arch arm64" \
    CFLAGS="-arch arm64 -mmacosx-version-min=11.0" \
    PKG_CONFIG_PATH="/opt/homebrew/opt/libogg/lib/pkgconfig:/opt/homebrew/opt/libvorbis/lib/pkgconfig:/opt/homebrew/opt/opus/lib/pkgconfig:/opt/homebrew/opt/flac/lib/pkgconfig:/opt/homebrew/opt/lame/lib/pkgconfig:/opt/homebrew/opt/portaudio/lib/pkgconfig:/opt/homebrew/opt/portmidi/lib/pkgconfig:/opt/homebrew/opt/libsamplerate/lib/pkgconfig:/opt/homebrew/opt/openssl@3/lib/pkgconfig:/opt/homebrew/opt/gettext/lib/pkgconfig:/opt/homebrew/opt/fltk/lib/pkgconfig"
```

**For Intel Macs**, replace `arm64` with `x86_64` and `/opt/homebrew` with `/usr/local`.

#### Step 5: Build

```bash
# Build (use -j4 for parallel compilation)
make -j4
```

**Expected output:**
```
...
clang++ ... -o butt butt.o cfg.o ... blackhole_output.o ...
...
```

#### Step 6: Create macOS Bundle

```bash
# Create .app bundle
./build_macos_bundle.sh
```

**Output:**
```
✅ Bundle créé avec succès!
📍 Emplacement: build/BUTT.app
```

#### Step 7: Install

```bash
# Install to Applications folder
sudo cp -R build/BUTT.app /Applications/
```

---

## 🎚️ StereoTool SDK Setup (Optional)

StereoTool SDK provides professional audio processing but is **optional**.

### Download SDK

1. Visit [stereo-tool.com](https://www.stereo-tool.com/download/)
2. Download **macOS SDK** (libStereoTool64.dylib)
3. Save the file

### License

- **Personal use**: FREE
- **Broadcast/Commercial**: PRO license required (~€300-500)
  - Purchase at [stereo-tool.com](https://www.stereo-tool.com/)

### Install SDK

```bash
# Place the SDK in your project root
cd /path/to/butt-enhanced
cp /path/to/downloads/libStereoTool64.dylib .

# Verify
ls -lh libStereoTool64.dylib
```

### Build with StereoTool

```bash
# Clean previous build
make clean

# Rebuild with SDK present
make -j4

# Create bundle (will include SDK)
./build_macos_bundle.sh
```

**Note**: The bundle will include the SDK, so **do not distribute** the bundle if you don't have distribution rights.

---

## 🚀 First Launch

### 1. Launch BUTT

```bash
open /Applications/BUTT.app
```

### 2. Grant Permissions

macOS will ask for permissions:
- ✅ **Microphone access** - Grant
- ✅ **Network connections** - Grant (for AES67)

### 3. Verify Initialization

Check Console.app or Terminal for:

```
✅ AES67: Output initialized
✅ BlackHole initialisé pour Whisper Streaming (sample_rate: 48000, channels: 2)
```

If StereoTool is present:
```
✅ StereoTool SDK loaded successfully
```

### 4. Select Audio Input

1. Go to **Settings → Audio**
2. Select your audio interface (e.g., CAPITOL IP, Focusrite)
3. Set sample rate: **48000 Hz**
4. Set channels: **2** (stereo)

---

## ⚙️ Configuration

### AES67 Output

1. Go to **Settings → AES67**
2. Configure:
   - **Enable**: ✅
   - **IP Address**: `239.69.145.58` (multicast) or your IP
   - **Port**: `5004`
   - **Sample Rate**: `48000 Hz`
   - **Bit Depth**: `16` or `24`
   - **Channels**: `2`
   - **Network Interface**: Select your Ethernet interface

3. **Optional**: Enable PTP for synchronization
4. **Optional**: Enable SAP announcements

### BlackHole Output

BlackHole is automatically configured. No manual setup needed!

To use with Whisper AI:

```bash
export WHISPER_AUDIO_SOURCE=blackhole
python whisper_streaming_service.py
```

### StereoTool Settings

1. Go to **Settings → StereoTool**
2. **Enable**: ✅
3. Load a preset (`.sts` file) or configure manually
4. **Optional**: Enable "Bypass on silence"

---

## 🧪 Testing

### Test Audio Input

1. Launch BUTT
2. Speak into your microphone
3. Check VU meters (should show activity)

### Test AES67 Output

```bash
# On the receiving machine (e.g., OBS)
# Install VLC or ffplay
brew install ffmpeg

# Listen to AES67 stream
ffplay -f sdp -i - << EOF
v=0
o=- 0 0 IN IP4 239.69.145.58
s=BUTT AES67
c=IN IP4 239.69.145.58/32
t=0 0
m=audio 5004 RTP/AVP 97
a=rtpmap:97 L24/48000/2
EOF
```

### Test BlackHole Output

```bash
# Listen to BlackHole
ffplay -f avfoundation -i ":BlackHole 2ch"
```

---

## 🔧 Troubleshooting

### Build Errors

#### Error: "configure: error: **** Could not find libogg ****"

**Solution:**
```bash
brew install libogg libvorbis opus flac lame
```

#### Error: "ld: library not found"

**Solution:**
```bash
# Add Homebrew lib path
export LIBRARY_PATH="/opt/homebrew/lib:$LIBRARY_PATH"

# Rebuild
make clean
./configure
make -j4
```

#### Error: Compilation warnings about deprecated functions

**Ignore** - These are harmless warnings from FLTK and don't affect functionality.

### Runtime Errors

#### "BlackHole non initialisé"

**Causes:**
- BlackHole not installed
- Permissions not granted

**Solution:**
```bash
# Reinstall BlackHole
brew reinstall blackhole-2ch

# Check permissions
# System Settings → Privacy & Security → Microphone
# Enable for BUTT
```

#### "AES67: Failed to initialize output"

**Causes:**
- Network interface not selected
- Multicast not supported on network
- Firewall blocking

**Solution:**
```bash
# Check network interfaces
ifconfig

# Test multicast
# (should show your Ethernet interface)
netstat -g | grep 239.69.145.58

# Disable firewall temporarily
sudo pfctl -d
```

#### No audio in OBS via AES67

**Solution:**

1. **Check network:**
   - Both machines on same subnet
   - Multicast enabled on switch

2. **Check OBS source:**
   - Add → Media Source
   - Local File → Browse
   - Select SDP file or create one:
     ```sdp
     v=0
     o=- 0 0 IN IP4 239.69.145.58
     s=BUTT AES67
     c=IN IP4 239.69.145.58/32
     t=0 0
     m=audio 5004 RTP/AVP 97
     a=rtpmap:97 L24/48000/2
     ```

3. **Check firewall:**
   - Allow UDP port 5004
   - Allow multicast

### Performance Issues

#### High CPU usage

**Solutions:**
- Disable StereoTool processing (if not needed)
- Reduce sample rate to 44100 Hz
- Close other applications

#### Audio dropouts

**Solutions:**
- Increase buffer size (Settings → Audio → Buffer)
- Use wired Ethernet (not WiFi) for AES67
- Check system load

---

## 📚 Additional Resources

- **[README.md](README.md)** - Project overview
- **[DEMARRAGE_RAPIDE_BLACKHOLE.md](DEMARRAGE_RAPIDE_BLACKHOLE.md)** - Quick start (French)
- **[INTEGRATION_BLACKHOLE_COMPLETE.md](INTEGRATION_BLACKHOLE_COMPLETE.md)** - Technical details
- **[CONTRIBUTING.md](CONTRIBUTING.md)** - Contribution guide

---

## 🆘 Still Having Issues?

1. **Check logs:**
   ```bash
   # Run from Terminal to see logs
   /Applications/BUTT.app/Contents/MacOS/BUTT
   ```

2. **Check GitHub Issues:**
   - [github.com/VOTRE_ORG/butt-enhanced/issues](https://github.com/VOTRE_ORG/butt-enhanced/issues)

3. **Ask for help:**
   - Create a new issue with:
     - macOS version
     - Hardware (M1/M2/Intel)
     - Error messages
     - Steps to reproduce

---

<div align="center">

**Happy Broadcasting! 🎙️**

📻 Made with ❤️ for the free radio community

</div>

