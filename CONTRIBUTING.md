# Contributing

Thanks for your interest in improving `swift-app-macros`. This is a small,
solo-maintained package, so a little structure keeps contributions easy to
review.

## Before you start

- For anything beyond a small fix, please **open an issue first** to discuss the
  change. This avoids duplicated work and confirms the change fits the project's
  scope (SwiftUI redraw optimization via `@Equatable`, `@SkipEquatable`, and
  `EquatableBodyView`).
- By contributing, you agree that your contributions are licensed under the
  project's [MIT License](LICENSE).

## Prerequisites

| Requirement  | Version                               |
|--------------|---------------------------------------|
| Swift tools  | **6.3** (Xcode 26.4+)                 |
| Platforms    | iOS 26+, macOS 26+                    |
| swift-syntax | `603.0.2` (exact pin — do not bump casually) |

## Building and testing

```bash
swift build
swift test        # runs the full macro + SwiftUI test suite
```

For SwiftUI-facing changes (`EquatableBodyView`), also verify the iOS build the
way CI does:

```bash
xcodebuild build -quiet \
  -scheme swift-app-macros \
  -destination "generic/platform=iOS Simulator"
```

## Pull requests

1. Fork and create a topic branch off `master`.
2. Keep changes focused; one logical change per PR.
3. Add or update tests for any behavior change. Macro output is easy to break
   silently, so a test that pins the expanded source is preferred.
4. Make sure `swift build` and `swift test` pass locally. CI
   (`.github/workflows/ci.yml`) must be green before a PR can merge.
5. Update `README.md` / `docs/` if you change public behavior.

## Coding conventions

- Match the surrounding style; do not reformat unrelated code.
- Prefer clear diagnostics over silent behavior in macro expansion — a
  contributor who misuses a macro should get an actionable error or warning.
- Document non-obvious design decisions in the code or in `docs/` rather than in
  the commit message alone.

## Reporting bugs and requesting features

Use the [issue templates](https://github.com/9uiLe/swift-app-macros/issues/new/choose).
For security issues, follow [SECURITY.md](SECURITY.md) instead of opening a
public issue.
