public enum EquatableExpansion: Sendable {
    case `extension`
    case nonisolated
}

/// Generates `Equatable` conformance from stored properties.
///
/// The default is automatic: structs that syntactically conform to `View` or
/// carry a global-actor attribute use a `nonisolated static func ==` member,
/// while other structs use an extension conformance. Pass `.extension` or
/// `.nonisolated` to force either shape.
///
/// Closure exclusion is syntactic. Function-typed properties are skipped, but
/// closure types hidden behind a typealias or inferred from a non-literal
/// initializer must be marked with `@SkipEquatable`.
///
/// When adopting this macro, delete any hand-written `static func ==` in the
/// same edit to avoid an invalid redeclaration.
@attached(extension, conformances: Equatable, names: named(==))
@attached(member, names: named(==))
public macro Equatable(_ expansion: EquatableExpansion? = nil) =
    #externalMacro(module: "AppMacrosMacros", type: "EquatableMacro")

/// Excludes one stored property from generated `Equatable` comparisons.
///
/// This marker applies to a single binding. Split multi-binding declarations
/// before marking a property, for example `let a = 1` and
/// `@SkipEquatable let b = makeHandler()`.
@attached(peer)
public macro SkipEquatable() =
    #externalMacro(module: "AppMacrosMacros", type: "SkipEquatableMacro")
