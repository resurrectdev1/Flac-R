# Changelog

All notable changes to Flac-R are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [Unreleased]

> Changes staged for the next release go here. Move them down when you cut a tag.

---

## [0.5.2] - 2026-07-18

### Added

* Banner for releases and GitHub page
* Analysis before build APK in actions workflow

### Changed

* Codebase to be more organized via dart format
* Onboarding sheet location from screens to widgets
* Lots of codebase cleanup and dependency upgrades, as well as optimizations for better performance and codebase maintainability

---

## [0.5.0] - 2026-06-19

### Added

* Library scan progress with current file tracking
* Batch editing support for Albums, Artists, and Folders
* Quick "Batch Edit All" actions in grouped views
* Onboarding disclaimer and large library guidance

### Changed

* Improved large library scanning performance
* Improved library scanning feedback and visibility
* Improved metadata loading performance
* Improved composer and comment tag loading efficiency
* Various UI polish and workflow improvements

### Fixed

* Various bug fixes and stability improvements

---

## [0.4.8] - 2026-06-10

### Added
- Support for .m4a, .ogg, and .aac audio formats
- App version in the info section now reads automatically from package metadata

### Changed
- Library now reloads automatically after onboarding, adding a folder, or removing a folder
- In-app text made more concise throughout

### Fixed
- Cached album art now updates correctly when the library is reloaded
- Year tagging field now has proper input safeguards

---

## [0.4.6] - 2026-06-03

### Added
- Initial release
- Cache logic for faster library loading
- Improved year tag support

### Changed
- UI consistent with Grove's design language

### Fixed
- Auto encoder tagging no longer applied incorrectly
- FLAC file now cached before editing to prevent data loss

---

<!--
HOW TO MAINTAIN THIS FILE
When you're ready to cut a new release:
1. Rename [Unreleased] to the new version and today's date, e.g.:
   ## [0.5.0] - 2026-07-01
2. Add a fresh empty [Unreleased] section at the top.
3. Use these section headers (only include the ones that apply):
   ### Added      — new features
   ### Changed    — changes to existing behaviour
   ### Deprecated — features to be removed in a future release
   ### Removed    — removed features
   ### Fixed      — bug fixes
   ### Security   — security-related changes
4. Keep entries short and user-facing. Write for someone reading the F-Droid
   update description, not for another developer reading the diff.
5. Commit the CHANGELOG update in the same commit as the pubspec version bump.
-->
