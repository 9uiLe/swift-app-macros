# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- **Breaking**: `@State` properties are now excluded from the generated `==`.
  After mounting, the source of truth for `@State` lives in AttributeGraph and
  the backing storage read by `==` only echoes the initializer snapshot, so the
  comparison was dead weight at best and a false negative at worst. `@State`
  mutations invalidate below the `.equatable()` gate, so the exclusion cannot
  go stale. This also unblocks non-Equatable `@State` values (e.g. `@Observable`
  models), which previously made the generated `==` fail to compile.
- Dynamic-property exclusion now follows witness isolation instead of expansion
  shape: `@Equatable(.extension)` forced on a `View` no longer includes
  environment/reference-derived wrappers in the comparison.
- **Breaking**: stored properties declared inside `#if` are now a compile-time
  error instead of being silently excluded from the generated `==` (the silent
  exclusion could keep a stale platform-specific view on screen). Mark them
  `@SkipEquatable` to exclude them explicitly, or declare them unconditionally.
  The view-like-struct warning now also detects a `body` declared inside `#if`.
- **Breaking**: a property whose type merely *contains* a function type
  (`[() -> Void]`, closures inside tuples or generic arguments) is now a
  compile-time error instead of being silently excluded — unlike a top-level
  callback, it is not obviously closure state, and dropping it silently could
  keep stale closures alive. Mark it `@SkipEquatable` to exclude it explicitly.
- New warning when every input was excluded from the comparison (closures,
  `@SkipEquatable`): the generated `==` is constant `true`, so a gated view
  would never re-render when those inputs change.

### Added

- Mounted render-suppression tests (`NSHostingView`) that assert the package's
  core contract: equal inputs skip `equatableBody` re-evaluation while parent
  invalidations and input changes propagate.

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
