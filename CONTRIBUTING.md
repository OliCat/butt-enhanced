# 🤝 Contributing to BUTT Enhanced

Thank you for your interest in contributing to BUTT Enhanced! This project is developed **for the free radio community** (radios libres), and we welcome contributions from everyone.

---

## 🌟 How to Contribute

### Ways to Contribute

1. **🐛 Report bugs** - Found an issue? Let us know!
2. **💡 Suggest features** - Have an idea? We'd love to hear it!
3. **📝 Improve documentation** - Help others understand the project
4. **💻 Submit code** - Fix bugs or add features
5. **🌍 Translate** - Help make BUTT accessible to more languages
6. **📢 Share** - Tell other radio stations about BUTT Enhanced

---

## 📋 Getting Started

### Prerequisites

- macOS 11.0 or later (currently macOS only)
- Xcode Command Line Tools
- Homebrew
- Basic knowledge of C++ (for code contributions)
- Git

### Development Setup

```bash
# 1. Fork the repository on GitHub
# 2. Clone your fork
git clone https://github.com/YOUR_USERNAME/butt-enhanced.git
cd butt-enhanced

# 3. Add upstream remote
git remote add upstream https://github.com/VOTRE_ORG/butt-enhanced.git

# 4. Install dependencies
brew install portaudio opus flac lame fltk libvorbis libogg \
             libsamplerate portmidi openssl gettext pkg-config \
             autoconf automake libtool blackhole-2ch

# 5. Configure in debug mode
./configure CXXFLAGS="-g -O0 -Wall"

# 6. Build
make -j4

# 7. Run
./src/butt
```

---

## 🐛 Reporting Bugs

### Before Reporting

1. Check [existing issues](https://github.com/VOTRE_ORG/butt-enhanced/issues)
2. Try with the latest version
3. Test without StereoTool (if applicable)

### Bug Report Template

```markdown
**Description**
A clear description of the bug.

**To Reproduce**
Steps to reproduce:
1. Go to '...'
2. Click on '...'
3. See error

**Expected Behavior**
What you expected to happen.

**Actual Behavior**
What actually happened.

**Environment**
- macOS version: [e.g., macOS 14.0]
- BUTT Enhanced version: [e.g., 1.45.0]
- Hardware: [e.g., Mac Studio M2, MacBook Pro M1]
- Audio interface: [e.g., CAPITOL IP, Focusrite]

**Logs**
```
Paste relevant logs here
```

**Screenshots**
If applicable, add screenshots.
```

---

## 💡 Suggesting Features

We love new ideas! Before suggesting:

1. Check [existing feature requests](https://github.com/VOTRE_ORG/butt-enhanced/issues?q=is%3Aissue+label%3Aenhancement)
2. Think about how it benefits the radio community
3. Consider implementation complexity

### Feature Request Template

```markdown
**Feature Description**
Clear description of the feature.

**Use Case**
Who would use this? When? Why?

**Example**
Real-world example of how it would work.

**Alternatives**
Other ways to achieve the same goal.

**Priority**
How important is this? (Nice to have / Important / Critical)
```

---

## 💻 Code Contributions

### Workflow

1. **Create a branch**
   ```bash
   git checkout -b feature/my-awesome-feature
   # or
   git checkout -b fix/bug-description
   ```

2. **Make your changes**
   - Write clean, readable code
   - Follow existing code style
   - Add comments for complex logic
   - Test thoroughly

3. **Commit your changes**
   ```bash
   git add .
   git commit -m "feat: add awesome feature"
   ```
   
   Use [Conventional Commits](https://www.conventionalcommits.org/):
   - `feat:` New feature
   - `fix:` Bug fix
   - `docs:` Documentation
   - `style:` Code style (formatting)
   - `refactor:` Code restructuring
   - `test:` Tests
   - `chore:` Maintenance

4. **Push and create Pull Request**
   ```bash
   git push origin feature/my-awesome-feature
   ```
   Then create a PR on GitHub.

### Code Style

- **Indentation**: 4 spaces (no tabs)
- **Line length**: Max 100 characters
- **Braces**: K&R style
- **Naming**:
  - Functions: `snake_case`
  - Classes: `PascalCase`
  - Variables: `snake_case`
  - Constants: `UPPER_CASE`

Example:
```cpp
class AudioProcessor {
private:
    int sample_rate_;
    bool is_initialized_;

public:
    bool initialize(int sample_rate) {
        if (sample_rate <= 0) {
            return false;
        }
        sample_rate_ = sample_rate;
        is_initialized_ = true;
        return true;
    }
};
```

### Testing

Before submitting:

```bash
# 1. Build without warnings
make clean
make -j4

# 2. Test basic functionality
./src/butt

# 3. Test AES67 output
# (if you modified AES67 code)

# 4. Test BlackHole output
# (if you modified BlackHole code)
```

---

## 📝 Documentation Contributions

Documentation is just as important as code!

### What to Document

- Installation steps
- Configuration guides
- Troubleshooting tips
- Use cases and examples
- API documentation (for developers)

### Documentation Style

- **Clear and concise** - Get to the point
- **Step-by-step** - Easy to follow
- **Examples** - Show, don't just tell
- **Screenshots** - A picture is worth 1000 words
- **Tested** - Verify your instructions work

---

## 🌍 Translations

Help make BUTT Enhanced accessible to more languages!

### Languages Needed

- 🇫🇷 French (Français)
- 🇪🇸 Spanish (Español)
- 🇩🇪 German (Deutsch)
- 🇮🇹 Italian (Italiano)
- 🇵🇹 Portuguese (Português)
- And more!

### Translation Workflow

1. Copy `po/butt.pot` to `po/YOUR_LANG.po`
2. Translate strings
3. Test with `LANG=YOUR_LANG ./src/butt`
4. Submit PR

---

## 📜 License

By contributing, you agree that your contributions will be licensed under the **GNU General Public License v2.0**.

---

## 🙏 Recognition

All contributors will be listed in [CONTRIBUTORS.md](CONTRIBUTORS.md).

---

## 💬 Communication

### Channels

- **GitHub Issues** - Bug reports, feature requests
- **GitHub Discussions** - General questions, ideas
- **Email** - [contact@causecommune.fm](mailto:contact@causecommune.fm)

### Response Time

We'll try to respond within:
- Bugs: 1-3 days
- Features: 1 week
- PRs: 1 week

---

## ✅ Pull Request Checklist

Before submitting a PR:

- [ ] Code compiles without errors
- [ ] Code follows project style
- [ ] Added/updated tests (if applicable)
- [ ] Updated documentation (if applicable)
- [ ] Tested manually
- [ ] Commit messages follow Conventional Commits
- [ ] PR description explains changes clearly

---

## 🎯 Priority Areas

We especially welcome contributions in:

1. **Windows support** - Port AES67/BlackHole features
2. **Linux support** - Complete platform support
3. **Documentation** - User guides, tutorials
4. **Testing** - Automated tests, CI/CD
5. **Translations** - Multi-language support
6. **Web interface** - Remote monitoring/control

---

## 🤔 Questions?

Not sure where to start? Have questions?

1. Check [existing documentation](docs/)
2. Look at [closed issues](https://github.com/VOTRE_ORG/butt-enhanced/issues?q=is%3Aissue+is%3Aclosed)
3. Ask in [GitHub Discussions](https://github.com/VOTRE_ORG/butt-enhanced/discussions)
4. Email us: [contact@causecommune.fm](mailto:contact@causecommune.fm)

---

## 🌟 Code of Conduct

### Our Pledge

We pledge to make participation in our project a harassment-free experience for everyone, regardless of age, body size, disability, ethnicity, gender identity and expression, level of experience, nationality, personal appearance, race, religion, or sexual identity and orientation.

### Our Standards

**Positive behavior:**
- Using welcoming and inclusive language
- Being respectful of differing viewpoints
- Gracefully accepting constructive criticism
- Focusing on what is best for the community
- Showing empathy towards other community members

**Unacceptable behavior:**
- Harassment, trolling, or discriminatory comments
- Publishing others' private information
- Other conduct which could reasonably be considered inappropriate

---

<div align="center">

**Thank you for contributing to BUTT Enhanced!**

Together, we're building better tools for free radio 📻

🤝 Every contribution matters | 🌍 Open Source | ❤️ Community-driven

</div>

