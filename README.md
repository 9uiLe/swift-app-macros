# AppMacros

[![Swift](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2F9uiLe%2Fswift-app-macros%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/9uiLe/swift-app-macros)
[![Platforms](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2F9uiLe%2Fswift-app-macros%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/9uiLe/swift-app-macros)

Generate equality for Swift structs and use it to suppress SwiftUI view updates
when parent inputs are equal.

The `AppMacros` library provides four APIs:

| API | Purpose |
| --- | --- |
| `@Equatable` | Generate `==` and `Equatable` conformance from stored properties |
| `@SkipEquatable` | Exclude a stored property from comparison |
| `EquatableBodyView` | Apply `.equatable()` through the view's default `body` |
| `@AutoEquatableView` | Generate a gated body for comparable inputs, with an ordinary View fallback for unsafe parent inputs |

## Quick start

`EquatableBodyView` defines a view with an equality boundary. Implement
`equatableBody` and use the view directly from SwiftUI.

```swift
import AppMacros
import SwiftUI

@Equatable
struct CounterRow: @MainActor EquatableBodyView {
    let value: Int

    var equatableBody: some View {
        Text(value.formatted())
    }
}

struct CounterScreen: View {
    let count: Int

    var body: some View {
        CounterRow(value: count)
    }
}
```

For a regular `View`, attach `@Equatable` and apply `.equatable()` where it is used.
For reusable views that can receive actions, bindings, or arbitrary child views,
`@AutoEquatableView` chooses the gate only when all parent-owned inputs are safe
to compare. See the [adaptive view guide](docs/auto-equatable-view.md).
Ordinary View equality and its conformance are MainActor-isolated. The
`.mainActor` and `.nonisolated` arguments select isolation explicitly;
`.extension` selects the placement of the comparison function.

Compared properties must capture the values that determine the view's display
and actions. Closures and known SwiftUI state wrappers are excluded. A change
only to an excluded property does not make the views unequal. See the
[usage guide](docs/adoption.md) for input and state ownership.

## Requirements

| Requirement | Version |
| --- | --- |
| Swift tools | 6.3 |
| Swift language mode | 6 |
| Platforms | iOS 26+, macOS 26+ |
| swift-syntax | 603.0.2, pinned exactly |

## Installation

Add the package dependency and link the `AppMacros` product from your target.

```swift
// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "YourApp",
    platforms: [.iOS(.v26), .macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/9uiLe/swift-app-macros.git", from: "0.3.0"),
    ],
    targets: [
        .target(
            name: "YourFeature",
            dependencies: [
                .product(name: "AppMacros", package: "swift-app-macros"),
            ]
        ),
    ]
)
```

Use a Swift tools 6.3 manifest. In Xcode, add
`https://github.com/9uiLe/swift-app-macros` as a package dependency and select
the `AppMacros` library for your app target.

## Documentation

The detailed guides are in Japanese.

| Topic | Contents |
| --- | --- |
| [Usage guide](docs/adoption.md) | Choose an API and define comparable inputs |
| [Design](docs/design.md) | Contracts, implementation modules, and test coverage |
| [`@Equatable`](docs/equatable.md) | Isolation, placement, property selection, generics, and diagnostics |
| [`@SkipEquatable`](docs/skip-equatable.md) | Property exclusion and its correctness conditions |
| [`EquatableBodyView`](docs/equatable-body-view.md) | View definition and state ownership |
| [`@AutoEquatableView`](docs/auto-equatable-view.md) | Safe automatic gating and fallback for reusable views |
| [Actor isolation](docs/actor-isolation.md) | Swift Evolution rules, Apple API contracts, and WWDC references |
| [Release design and operations](docs/releasing.md) | Publication model, commands, recovery, and repository protection |

## Development

```sh
swift build
swift test
```

The suite covers macro expansion, compiled equality, and mounted macOS views.
CI validates the Swift package, the iOS Simulator build, and release tooling on
PRs and pushes to `master`. See [CONTRIBUTING.md](CONTRIBUTING.md) for the
development environment, checks, and contribution process.

## Releases and maintenance

`9uiLe` maintains this public repository and publishes source releases. Changes
enter `master` through PRs. Local release commands use the owner's GitHub CLI
authentication to prepare version PRs and publish commits that pass `master` CI.
GitHub Actions runs with read-only credentials.

Each package version has an annotated Git tag and a GitHub Release containing
its [CHANGELOG](CHANGELOG.md) entries. The [release guide](docs/releasing.md)
defines the workflow and publication requirements.

## Community and license

Follow the [Code of Conduct](CODE_OF_CONDUCT.md). Report security issues using
the [Security Policy](SECURITY.md).

MIT — see [LICENSE](LICENSE).
