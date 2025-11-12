# 🎙️ BUTT Enhanced

**Enhanced version of BUTT (Broadcast Using This Tool) for professional radio broadcasting**

Developed for and by the **free radio community** (radios libres) 📻

[![License: GPL v2](https://img.shields.io/badge/License-GPL%20v2-blue.svg)](https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html)
[![Platform: macOS](https://img.shields.io/badge/Platform-macOS-lightgrey.svg)](https://www.apple.com/macos/)
[![Arch: ARM64](https://img.shields.io/badge/Arch-ARM64-green.svg)](https://en.wikipedia.org/wiki/ARM_architecture)

---

## 🌟 Features

This enhanced version adds professional broadcasting features to BUTT:

### 🌐 AES67 Audio-over-IP Output
- **Industry-standard** AES67 audio streaming
- Multicast support (239.69.145.58:5004 default)
- **OBS integration** via GStreamer pipeline (see [docs/README_AES67_OBS.md](docs/README_AES67_OBS.md))
- PTP synchronization support
- SAP announcements for automatic discovery
- Configurable sample rate, bit depth, and channels

### 🎙️ BlackHole Output
- Real-time audio output to **BlackHole** virtual audio device
- Perfect for **Whisper AI** transcription integration
- Zero-latency monitoring
- Simultaneous output with AES67

### 🎚️ StereoTool SDK Integration (Optional)
- Professional audio processing
- Compatible with StereoTool PRO license
- Bypass on silence support
- Real-time VU meters (pre/post processing)

---

## 📋 Architecture

```
USB Audio Interface (e.g., CAPITOL IP)
    ↓
BUTT Enhanced
    ↓
StereoTool Processing (optional)
    ↓
    ├── → AES67 (239.69.145.58:5004) → OBS Machine
    └── → BlackHole 2ch → Whisper AI / Real-time processing
```

---

## 🚀 Quick Start

### Prerequisites

1. **macOS** 11.0 or later (Apple Silicon or Intel)
2. **Homebrew** package manager
3. **BlackHole** virtual audio driver:
   ```bash
   brew install blackhole-2ch
   ```

### Installation

#### Option 1: Download Pre-built Bundle (Recommended)
*Coming soon on releases page*

#### Option 2: Build from Source

```bash
# 1. Install dependencies
brew install portaudio opus flac lame fltk libvorbis libogg \
             libsamplerate portmidi openssl gettext pkg-config \
             autoconf automake libtool

# 2. Clone repository
git clone https://github.com/OliCat/butt-enhanced.git
cd butt-enhanced

# 3. (Optional) Download StereoTool SDK
# See INSTALLATION.md for details
# Place libStereoTool64.dylib in project root

# 4. Configure and build
./configure
make -j4

# 5. Create macOS bundle
./build_macos_bundle.sh

# 6. Install
sudo cp -R build/BUTT.app /Applications/
```

### First Launch

```bash
open /Applications/BUTT.app
```

You should see in the console:
```
✅ AES67: Output initialized
✅ BlackHole initialisé pour Whisper Streaming (sample_rate: 48000, channels: 2)
```

---

## 📖 Documentation

- **[docs/DOCUMENTATION_COMPLETE.md](docs/DOCUMENTATION_COMPLETE.md)** - Complete documentation (French)
- **[docs/README_AES67_OBS.md](docs/README_AES67_OBS.md)** - AES67 integration with OBS Studio (complete setup guide)
- **[docs/README.md](docs/README.md)** - Documentation index

---

## ⚙️ Configuration

### AES67 Setup

1. Launch BUTT Enhanced
2. Go to Settings → AES67
3. Configure:
   - IP: `239.69.145.58` (multicast)
   - Port: `5004`
   - Sample rate: `48000 Hz`
   - Channels: `2` (stereo)
   - Bit depth: `16` or `24`

### BlackHole Setup

BlackHole is automatically initialized at startup. To use with Whisper AI:

```bash
export WHISPER_AUDIO_SOURCE=blackhole
python whisper_streaming_service.py
```

### StereoTool Setup (Optional)

1. Download SDK from [Thimeo](https://www.thimeo.com/stereo-tool/)
2. For broadcast use, purchase a PRO license
3. Place `libStereoTool64.dylib` in project root before compilation
4. Enable in BUTT Settings → StereoTool

---

## 🤝 Contributing

We welcome contributions from the community! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Development Setup

```bash
# Clone with development branches
git clone -b develop https://github.com/OliCat/butt-enhanced.git

# Build in debug mode
./configure CXXFLAGS="-g -O0"
make

# Run tests
make check
```

---

## 📜 License

### BUTT Enhanced Code

This project is licensed under **GNU General Public License v2.0** - see [LICENSE](LICENSE) file for details.

Based on [BUTT](https://danielnoethen.de/butt/) by Daniel Nöthen.

### StereoTool SDK
**NOT INCLUDED** in this distribution.

- **License**: Proprietary (© Hans van Zutphen / Thimeo)
- **Free** for personal use
- **PRO license required** for broadcast/commercial use
- Download from: [www.thimeo.com](https://www.thimeo.com/stereo-tool/)

### Dependencies
See [LICENSE-DEPENDENCIES.md](LICENSE-DEPENDENCIES.md) for full list of dependencies and their licenses.

---

## 🙏 Credits

### Original BUTT
- **Author**: Daniel Nöthen
- **Website**: [danielnoethen.de/butt](https://danielnoethen.de/butt/)
- **License**: GPL v2

### BUTT Enhanced
- **Developed for**: [Radio Cause Commune](https://www.causecommune.fm/) (Paris, France)
- **Contributors**: See [CONTRIBUTORS.md](CONTRIBUTORS.md)

### Special Thanks
- StereoTool by Hans van Zutphen
- BlackHole Audio Driver by Existential Audio
- The free radio community (radios libres)

---

## 📞 Support

### Issues & Bug Reports
- GitHub Issues: [github.com/OliCat/butt-enhanced/issues](https://github.com/OliCat/butt-enhanced/issues)

### Community
- Radio Cause Commune: [causecommune.fm](https://www.causecommune.fm/)
- BUTT Official: [danielnoethen.de/butt](https://danielnoethen.de/butt/)

### Documentation
- Full documentation: [butt-enhanced.readthedocs.io](https://butt-enhanced.readthedocs.io/) *(coming soon)*

---

## 🎯 Use Cases

This enhanced version is perfect for:

- 📻 **Community radio stations** (radios associatives)
- 🎙️ **Podcast studios** with professional audio processing
- 🌐 **AoIP workflows** (Audio-over-IP)
- 🤖 **AI-powered transcription** (Whisper integration)
- 🎬 **Remote broadcasting** to OBS/vMix via network

---

## 🗺️ Roadmap

See [ROADMAP.md](ROADMAP.md) for planned features.

- [ ] Windows support for AES67/BlackHole
- [ ] Linux support
- [ ] Web-based monitoring interface
- [ ] Multi-stream AES67 support
- [ ] Built-in audio recorder with StereoTool processing

---

## ⚠️ Important Notes

### Performance
- **CPU**: < 5% on Apple M1/M2
- **RAM**: < 100 MB
- **Latency**: < 10ms (AES67 + BlackHole)

### Network Requirements
For AES67:
- Gigabit Ethernet recommended
- Multicast-capable network switch
- PTP for synchronization (optional but recommended)

### Compatibility
- ✅ macOS 11.0+ (Big Sur or later)
- ✅ Apple Silicon (M1/M2/M3) - Native ARM64
- ✅ Intel Macs (x86_64)
- ⚠️ Windows/Linux: AES67 only (BlackHole not available)

---

## 📊 Status

- ✅ **Production-ready** on macOS
- ✅ Used daily at Radio Cause Commune
- ✅ Stable for 24/7 broadcasting
- 🧪 Windows/Linux ports: Experimental

---

<div align="center">

**Made with ❤️ for the free radio community**

🎙️ [Radio Cause Commune](https://www.causecommune.fm/) | 📡 Broadcast Free | 🔓 Open Source

</div>

