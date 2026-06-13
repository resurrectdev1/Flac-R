# Contributing to Flac-R

Thanks for your interest in contributing! Flac-R is free, open-source software built for everbody, any help is welcome, whether that's code, bug reports, or ideas.

---

## Reporting Bugs & Requesting Features

Found something broken? Have an idea? You can reach out however works best for you:

- **GitHub Issues** — preferred for bugs and feature requests so they're tracked
- **GitHub Discussions** — great for open-ended ideas or questions
- **Wherever** — if you find another way to reach me, that's fine too

When reporting a bug, try to include:
- Your Android version and device
- Steps to reproduce the issue
- What you expected vs. what actually happened
- Logs or screenshots if you have them

---

## Contributing Code

1. **Open an issue first** for anything significant, it avoids duplicate work and lets us align before you invest time writing code
2. Fork the repo and create a branch from `main`
3. Make your changes, keep commits focused and readable
4. Test on a real device with actual audio files if possible, not just an emulator
5. Open a pull request with a clear description of what you changed and why

### Guidelines

- Follow the existing code style, when in doubt, match what's already there
- Keep pull requests scoped to one thing; big mixed PRs are hard to review
- Update the `CHANGELOG.md` under `[Unreleased]` with any user-facing changes
- Bump `pubspec.yaml` only if we've agreed on a version bump

### What's welcome

- Bug fixes
- Performance improvements
- Accessibility improvements
- Additional audio format support
- Tag editing improvements

### What to check first

- There's no open issue or PR already covering your change
- The change aligns with Flac-R's scope: local audio tag editing, fully offline

---

## Project Philosophy

Flac-R is FOSS software built for people, not profit. Contributions should respect that:

- No telemetry, analytics, or data collection of any kind
- No external dependencies that phone home
- Your music library stays on your device — always

---

## Development Setup

1. Make sure you have [Flutter](https://flutter.dev/docs/get-started/install) installed
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/Flac-R.git`
3. Install dependencies: `flutter pub get`
4. Run on a connected device or emulator: `flutter run`

---

## License

By contributing, you agree that your contributions will be licensed under the same [GPL-3.0 License](LICENSE) that covers this project.
