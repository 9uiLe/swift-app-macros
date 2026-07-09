# AppMacros documentation

Detailed reference for the macros shipped by
[`swift-app-macros`](../README.md). Start with the rationale, then read the
reference for the specific API you need.

## Contents

| Page | What it covers |
|------|----------------|
| [Rationale](rationale.md) | Why an `Equatable` macro exists — the SwiftUI / Swift 6 pitfalls it removes |
| [`@Equatable`](equatable.md) | Generated `Equatable` conformance: generation form, auto-exclusions, generics, examples |
| [`@SkipEquatable`](skip-equatable.md) | Excluding a specific stored property from comparison |
| [`EquatableBodyView`](equatable-body-view.md) | Baking `.equatable()` into the view definition (ADR-0015) |
| [Adoption guide](adoption.md) | Safe adoption checklist and known limitations |

For a quick start, installation, and compatibility, see the
[top-level README](../README.md).
