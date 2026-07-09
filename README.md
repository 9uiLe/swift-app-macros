# AppMacros

Production-oriented Swift macros for app development.

`swift-app-macros` ships [`AppMacros`](Sources/AppMacros): SwiftUI redraw
optimization via `@Equatable`, `@SkipEquatable`, and `EquatableBodyView`.

## Quick start

```swift
import AppMacros
import SwiftUI

@Equatable
struct CounterRow: EquatableBodyView {
    let value: Int

    var equatableBody: some View {
        Text("\(value)")
    }
}

// No `.equatable()` at call sites — baked into EquatableBodyView.
CounterRow(value: 1)
```

For intermediate views, use `@Equatable` and apply `.equatable()` at the call site.

## Compatibility

| Requirement | Version |
|---|---|
| Swift tools | **6.3** (`swiftLanguageModes: [.v6]`) |
| Platforms | **iOS 26+**, **macOS 26+** |
| swift-syntax | `603.0.2` (exact pin) |

This is an early package targeting the latest Apple SDKs. Older OS / Swift versions are not supported.

## Installation

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/9uiLe/swift-app-macros.git", from: "0.1.0"),
],
targets: [
    .target(name: "YourFeature", dependencies: [
        .product(name: "AppMacros", package: "swift-app-macros"),
    ]),
]
```

## Documentation

The three APIs and the reasoning behind them are documented in [`docs/`](docs/README.md):

| Topic | Summary |
|-------|---------|
| [Rationale](docs/rationale.md) | Why an `Equatable` macro — the SwiftUI / Swift 6 pitfalls it removes |
| [`@Equatable`](docs/equatable.md) | Generated conformance: generation form, auto-exclusions, generics, examples |
| [`@SkipEquatable`](docs/skip-equatable.md) | Exclude a specific stored property from comparison |
| [`EquatableBodyView`](docs/equatable-body-view.md) | Bake `.equatable()` into the view definition |
| [Adoption guide](docs/adoption.md) | Safe adoption checklist and known limitations |

## Testing

```bash
swift test   # 44 tests / 4 suites
```

CI runs on pull requests (`.github/workflows/ci.yml`).

## Changelog

Release notes are in [CHANGELOG.md](CHANGELOG.md).

## Contributing

Contributions are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md) and the
[Code of Conduct](CODE_OF_CONDUCT.md). For security issues, follow the
[Security Policy](SECURITY.md) instead of opening a public issue.

## License

MIT — see [LICENSE](LICENSE).
