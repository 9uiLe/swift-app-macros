# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-07-10

Initial public release.

### Added

- `@Equatable` — generates `Equatable` conformance from stored properties and
  automatically picks the generation form: a `nonisolated static func ==` member
  for `View` / global-actor types, or an `extension` conformance otherwise.
  Explicit override via `@Equatable(.nonisolated)` / `@Equatable(.extension)`.
- Automatic exclusion of computed properties, `body`, `static`/`class`/`lazy`
  members, function/closure-typed properties, and (in `.nonisolated` form)
  environment-derived SwiftUI dynamic properties. `@State` is intentionally
  included in comparison.
- `@SkipEquatable` — excludes a specific stored property from the generated
  comparison.
- `EquatableBodyView` — bakes `.equatable()` into the view definition so call
  sites can't silently forget it; the content goes in `equatableBody`.
- Diagnostics that reject unsafe usage (non-Equatable dynamic properties on an
  `EquatableBodyView` conformer, a directly declared `body`, `@SkipEquatable`
  misuse, and hand-written `==` alongside `@Equatable`).
- Documentation under [`docs/`](docs/README.md) and CI on pull requests.

### Requirements

- Swift tools 6.3 (Xcode 26.4+), iOS 26+, macOS 26+, swift-syntax `603.0.2`.

[Unreleased]: https://github.com/9uiLe/swift-app-macros/compare/0.1.0...HEAD
[0.1.0]: https://github.com/9uiLe/swift-app-macros/releases/tag/0.1.0
