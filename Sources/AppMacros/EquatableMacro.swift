/// Controls the placement or isolation of generated equality.
public enum EquatableExpansion: Sendable {
    /// Places equality in an extension with automatic actor isolation.
    case `extension`
    /// Isolates equality and its conformance to MainActor.
    case mainActor
    /// Generates a nonisolated equality member.
    /// Compared properties must be accessible and comparable from nonisolated code.
    case nonisolated
}

/// Generates equality and `Equatable` conformance for a struct's stored inputs.
///
/// Automatic isolation follows an explicitly isolated `Equatable` or
/// `EquatableBodyView` conformance, a `nonisolated` type declaration, a recognized
/// global-actor attribute, or a direct `View` conformance, in that order.
/// Ordinary views use MainActor. Global-actor attributes are recognized as
/// `MainActor` or names ending in `Actor` with at least six characters.
/// Without a recognized isolation, equality is generated in an extension and
/// follows the compiler's isolation inference.
///
/// Pass `.mainActor` or `.nonisolated` to select isolation explicitly, or
/// `.extension` to place equality in an extension with automatic isolation.
/// The argument must directly name an enum case or be `nil`.
///
/// Directly declared `Equatable`, `EquatableBodyView`, `Hashable`, and `Comparable`
/// conformances must match the comparison's isolation. For a MainActor view,
/// write `: @MainActor EquatableBodyView` or `: View, @MainActor Equatable`, or
/// let the macro add Equatable conformance to a `View` declaration.
/// `InferIsolatedConformances` is not required.
///
/// Computed, static, and lazy properties, top-level closures, known SwiftUI
/// dynamic properties, and properties marked `@SkipEquatable` are excluded.
/// Excluded values do not affect equality. A view using `.equatable()` must
/// remain correct when those values change without a compared input changing.
///
/// Closure detection uses syntax. Mark closures hidden behind a typealias or
/// inferred from a non-literal initializer with `@SkipEquatable` to exclude them.
/// Do not declare a competing equality operator. Invalid declarations produce
/// diagnostics without a generated comparison or additional conformance.
@attached(extension, conformances: Equatable, names: named(==))
@attached(member, names: named(==))
public macro Equatable(_ expansion: EquatableExpansion? = nil) =
    #externalMacro(module: "AppMacrosMacros", type: "EquatableMacro")

/// Excludes one stored property from generated `Equatable` comparisons.
///
/// Apply this marker to a declaration containing one stored property.
/// A change to the excluded value does not make instances unequal. When equality
/// gates view updates, using the previous excluded value must remain correct.
@attached(peer)
public macro SkipEquatable() =
    #externalMacro(module: "AppMacrosMacros", type: "SkipEquatableMacro")

/// Adds an equality boundary when every parent-owned input can be compared.
///
/// Apply to a struct that directly conforms to `View` and implements
/// `equatableBody`. Stored closures, `@SkipEquatable`, `@Binding`, `@Bindable`,
/// and `@ObservedObject` make the view use an ordinary `body` instead of an
/// equality boundary. Other known SwiftUI dynamic properties are managed by
/// SwiftUI and remain outside the comparison.
///
/// The fallback preserves updates when an action, source, or arbitrary child
/// view changes. Its instances do not conform to `Equatable` automatically.
@attached(member, names: named(body), named(==))
@attached(extension, conformances: EquatableBodyView, Equatable, names: named(==))
public macro AutoEquatableView() =
    #externalMacro(module: "AppMacrosMacros", type: "AutoEquatableViewMacro")
