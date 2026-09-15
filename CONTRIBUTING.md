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
swift test
```

For SwiftUI-facing changes (`EquatableBodyView`), also verify the iOS build the
way CI does:

```bash
xcodebuild build -quiet \
  -scheme swift-app-macros \
  -destination "generic/platform=iOS Simulator"
```

`swift test` covers macro expansion and diagnostics, compiled comparisons, and
mounted macOS SwiftUI views. The iOS command verifies compilation; it does not
run the macOS rendering tests on iOS.

For release tooling changes, use Python 3.10 or later:

```bash
python3 -m unittest discover -s scripts/tests -v
```

These tests use temporary Git repositories and a simulated GitHub service;
they need neither GitHub credentials nor network access.

## Architecture

Read the [design overview](docs/design.md) for the public contracts and the
source and test map. The [actor isolation design](docs/actor-isolation.md)
connects the generated code to Swift Evolution and SwiftUI API requirements.

Property selection, actor isolation, and comparison placement are independent
policies. Keep their behavior consistent across the member and extension macro
roles. Invalid declarations must produce diagnostics without partial equality
code or conformance generation.

## Pull requests

1. Fork and create a topic branch off `master`.
2. Keep changes focused; one logical change per PR.
3. Add or update tests for any behavior change. Macro output is easy to break
   silently, so a test that pins the expanded source is preferred.
4. Make sure `swift build` and `swift test` pass locally. CI
   (`.github/workflows/ci.yml`) must be green before a PR can merge.
5. Update `README.md` / `docs/` if you change public behavior.

The owner merges PRs after `Swift package checks` and `Release tooling checks`
pass and review discussions are resolved. Approving reviews are optional for
this solo-maintained repository.

## Releases

Only `9uiLe` changes the upstream repository and publishes releases. Public
issues and fork PRs are welcome; they do not grant upstream write access.
Keep release entries in `CHANGELOG.md` under `Unreleased`. The owner chooses
the version and follows the [release procedure](docs/releasing.md).

## Coding conventions

- Match the surrounding style; do not reformat unrelated code.
- Prefer clear diagnostics over silent behavior in macro expansion — a
  contributor who misuses a macro should get an actionable error or warning.
- Follow [AGENTS.md](AGENTS.md): behavior belongs in code, requirements in tests,
  change motivation in commit messages, and non-obvious constraints or rejected
  alternatives in code comments. Public DocC comments describe the contract.

## Reporting bugs and requesting features

Use the [issue templates](https://github.com/9uiLe/swift-app-macros/issues/new/choose).
For security issues, follow [SECURITY.md](SECURITY.md) instead of opening a
public issue.
