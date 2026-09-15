# Contributing

AppMacros provides equality generation for Swift structs and equality boundaries
for SwiftUI views. Development focuses on the contracts of `@Equatable`,
`@SkipEquatable`, and `EquatableBodyView`.

The repository is public. Anyone can report issues or propose changes through a
fork PR. The owner, `9uiLe`, controls upstream writes, merges, and releases.
Contributions are distributed under the [MIT License](LICENSE).

## Start with the relevant guide

| Area | Guide |
| --- | --- |
| Public API and implementation structure | [Design overview](docs/design.md) |
| Swift concurrency and generated conformances | [Actor isolation](docs/actor-isolation.md) |
| Release tooling, publication, and repository protection | [Release design and operations](docs/releasing.md) |

Open an [issue](https://github.com/9uiLe/swift-app-macros/issues/new/choose) to
discuss changes beyond a small fix. Describe the expected behavior and the use
case it supports. Report security issues through [SECURITY.md](SECURITY.md).

## Development environment

| Component | Requirement |
| --- | --- |
| Swift tools | 6.3, supplied by Xcode 26.4 or later |
| Swift language mode | 6 |
| Target platforms | iOS 26+, macOS 26+ |
| swift-syntax | 603.0.2, pinned exactly |
| Release tooling tests | Python 3.10+ and Git |
| Release commands | Python 3.10+, Git, and GitHub CLI authenticated as the owner |

The Swift tools version and SwiftSyntax pin define compiler compatibility.
Change them only when the package's compiler requirements call for it.

## Implementing a change

1. Create a topic branch from `master`; external contributors work in a fork.
2. Express each behavior change in tests. Macro tests should assert generated
   source and diagnostics; runtime tests should assert observable behavior.
3. Update API documentation and usage examples when public contracts change.
4. Describe user-facing changes under `Unreleased` in `CHANGELOG.md`. Mark
   breaking changes and explain the required consumer action. Use complete URLs
   because these entries also form the GitHub Release notes.
5. Run the checks relevant to the change and open a PR against `master`.

Property selection, actor isolation, and comparison placement are independent
macro policies. Member and extension roles use the same expansion plan. Invalid
declarations produce diagnostics without partial equality or conformance code.

Follow [AGENTS.md](AGENTS.md): behavior belongs in code, requirements in tests,
change motivation in commit messages, and non-obvious constraints or rejected
alternatives in implementation comments. Public DocC comments describe API
contracts. Match surrounding style and provide actionable diagnostics.

## Validation

Build and test the Swift package on macOS:

```sh
swift build
swift test
```

The Swift tests cover macro expansion, diagnostics, compiled equality, actor
isolation, and views mounted in a macOS SwiftUI hierarchy.

Compile the package for iOS Simulator:

```sh
xcodebuild build -quiet \
  -scheme swift-app-macros \
  -destination "generic/platform=iOS Simulator"
```

Run the release tooling tests:

```sh
python3 -m unittest discover -s scripts/tests -v
```

Release tests use temporary Git repositories and simulated GitHub responses.
They verify preparation, publication conditions, and recovery without GitHub
credentials or network access.

## Review and merge

The [CI workflow](.github/workflows/ci.yml) runs on PRs and pushes to `master`.
Both `Swift package checks` and `Release tooling checks` are required. A PR must
be current with its base branch and have resolved review conversations. Required
approving reviews are set to zero for this solo-maintained repository.

The owner reviews the code, tests, documentation, and compatibility impact, then
merges the PR. Repository Admin can bypass rules through a PR. Publication still
requires successful CI for the merged `master` commit.

## Releasing

The owner chooses a version, runs `scripts/release.py prepare X.Y.Z`, and reviews
the resulting version PR. After merging and waiting for `master` CI, the owner
runs `check X.Y.Z` and `publish X.Y.Z`.

The [release guide](docs/releasing.md) defines authentication, version selection,
publication conditions, retry behavior, and GitHub protection settings.
