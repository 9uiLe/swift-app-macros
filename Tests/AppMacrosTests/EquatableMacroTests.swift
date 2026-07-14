import AppMacros
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

#if canImport(AppMacrosMacros)
    import AppMacrosMacros

    let testMacros: [String: Macro.Type] = [
        "Equatable": EquatableMacro.self,
        "SkipEquatable": SkipEquatableMacro.self,
    ]
#endif

@Suite("Equatable Macro")
struct EquatableMacroTests {
    @Test("non-View default emits extension conformance")
    func nonViewDefaultEmitsExtensionConformance() throws {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable
                struct User {
                    let id: Int
                    let name: String
                }
                """,
                expandedSource: """
                struct User {
                    let id: Int
                    let name: String
                }

                extension User: Equatable {
                    static func == (lhs: User, rhs: User) -> Bool {
                        return lhs.id == rhs.id && lhs.name == rhs.name
                    }
                }
                """,
                macros: testMacros,
            )
        #endif
    }

    @Test("View default emits nonisolated member")
    func viewDefaultEmitsNonisolatedMember() throws {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable
                struct CounterView: View, Equatable {
                    let value: Int
                    let action: @MainActor () -> Void

                    var body: some View {
                        Text("\\(value)")
                    }
                }
                """,
                expandedSource: """
                struct CounterView: View, Equatable {
                    let value: Int
                    let action: @MainActor () -> Void

                    var body: some View {
                        Text("\\(value)")
                    }

                    nonisolated static func == (lhs: CounterView, rhs: CounterView) -> Bool {
                        return lhs.value == rhs.value
                    }
                }
                """,
                macros: testMacros,
            )
        #endif
    }

    @Test("View default adds Equatable conformance when missing")
    func viewDefaultAddsEquatableConformanceWhenMissing() throws {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable
                struct CounterView: SwiftUI.View {
                    let value: Int

                    var body: some SwiftUI.View {
                        Text("\\(value)")
                    }
                }
                """,
                expandedSource: """
                struct CounterView: SwiftUI.View {
                    let value: Int

                    var body: some SwiftUI.View {
                        Text("\\(value)")
                    }

                    nonisolated static func == (lhs: CounterView, rhs: CounterView) -> Bool {
                        return lhs.value == rhs.value
                    }
                }

                extension CounterView: Equatable {
                }
                """,
                macros: testMacros,
            )
        #endif
    }

    @Test("explicit nonisolated emits member for non-View")
    func explicitNonisolatedEmitsMemberForNonView() throws {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable(.nonisolated)
                struct Row {
                    let state: Int
                    let action: () -> Void
                }
                """,
                expandedSource: """
                struct Row {
                    let state: Int
                    let action: () -> Void

                    nonisolated static func == (lhs: Row, rhs: Row) -> Bool {
                        return lhs.state == rhs.state
                    }
                }

                extension Row: Equatable {
                }
                """,
                macros: testMacros,
            )
        #endif
    }

    @Test("explicit extension can be forced on View")
    func explicitExtensionCanBeForcedOnView() throws {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable(.extension)
                struct CounterView: View {
                    let value: Int

                    var body: some View {
                        Text("\\(value)")
                    }
                }
                """,
                expandedSource: """
                struct CounterView: View {
                    let value: Int

                    var body: some View {
                        Text("\\(value)")
                    }
                }

                extension CounterView: Equatable {
                    nonisolated static func == (lhs: CounterView, rhs: CounterView) -> Bool {
                        return lhs.value == rhs.value
                    }
                }
                """,
                macros: testMacros,
            )
        #endif
    }

    @Test("MainActor default emits nonisolated member")
    func mainActorDefaultEmitsNonisolatedMember() throws {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @MainActor
                @Equatable
                struct Model {
                    let value: Int
                }
                """,
                expandedSource: """
                @MainActor
                struct Model {
                    let value: Int

                    nonisolated static func == (lhs: Model, rhs: Model) -> Bool {
                        return lhs.value == rhs.value
                    }
                }

                extension Model: Equatable {
                }
                """,
                macros: testMacros,
            )
        #endif
    }

    @Test("empty struct compares true")
    func emptyStructComparesTrue() throws {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable
                struct Empty {}
                """,
                expandedSource: """
                struct Empty {}

                extension Empty: Equatable {
                    static func == (lhs: Empty, rhs: Empty) -> Bool {
                        return true
                    }
                }
                """,
                macros: testMacros,
            )
        #endif
    }

    @Test("lazy properties are excluded")
    func lazyPropertiesAreExcluded() throws {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable
                struct User {
                    let id: Int
                    lazy var cachedName = "name"
                }
                """,
                expandedSource: """
                struct User {
                    let id: Int
                    lazy var cachedName = "name"
                }

                extension User: Equatable {
                    static func == (lhs: User, rhs: User) -> Bool {
                        return lhs.id == rhs.id
                    }
                }
                """,
                macros: testMacros,
            )
        #endif
    }

    @Test("computed and static properties are excluded")
    func computedAndStaticPropertiesAreExcluded() throws {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable
                struct User {
                    let id: Int
                    var name: String { "A" }
                    static let cacheKey = "user"
                    class var classValue: Int { 1 }
                }
                """,
                expandedSource: """
                struct User {
                    let id: Int
                    var name: String { "A" }
                    static let cacheKey = "user"
                    class var classValue: Int { 1 }
                }

                extension User: Equatable {
                    static func == (lhs: User, rhs: User) -> Bool {
                        return lhs.id == rhs.id
                    }
                }
                """,
                macros: testMacros,
            )
        #endif
    }

    @Test("stored properties with observers are included")
    func storedPropertiesWithObserversAreIncluded() throws {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable
                struct User {
                    var count: Int {
                        willSet {}
                        didSet {}
                    }
                }
                """,
                expandedSource: """
                struct User {
                    var count: Int {
                        willSet {}
                        didSet {}
                    }
                }

                extension User: Equatable {
                    static func == (lhs: User, rhs: User) -> Bool {
                        return lhs.count == rhs.count
                    }
                }
                """,
                macros: testMacros,
            )
        #endif
    }

    @Test("stored property inside #if is diagnosed, not silently dropped")
    func storedPropertyInsideConditionalBlockIsDiagnosed() throws {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable
                struct S {
                    let id: Int
                    #if os(iOS)
                    let platformValue: Int
                    #endif
                }
                """,
                expandedSource: """
                struct S {
                    let id: Int
                    #if os(iOS)
                    let platformValue: Int
                    #endif
                }

                extension S: Equatable {
                    static func == (lhs: S, rhs: S) -> Bool {
                        return lhs.id == rhs.id
                    }
                }
                """,
                diagnostics: [
                    DiagnosticSpec(
                        message: "@Equatable does not compare stored properties declared inside #if — the generated == would silently ignore platform-specific changes (stale view); mark it with @SkipEquatable to exclude it explicitly, or declare it unconditionally",
                        line: 5,
                        column: 5,
                    ),
                ],
                macros: testMacros,
            )
        #endif
    }

    @Test("stored property inside #if can be skipped explicitly")
    func storedPropertyInsideConditionalBlockCanBeSkippedExplicitly() throws {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable
                struct S {
                    let id: Int
                    #if os(iOS)
                    @SkipEquatable let platformValue: Int
                    #endif
                }
                """,
                expandedSource: """
                struct S {
                    let id: Int
                    #if os(iOS)
                    let platformValue: Int
                    #endif
                }

                extension S: Equatable {
                    static func == (lhs: S, rhs: S) -> Bool {
                        return lhs.id == rhs.id
                    }
                }
                """,
                macros: testMacros,
            )
        #endif
    }

    @Test("multi-binding vars compare every identifier")
    func multiBindingVarsCompareEveryIdentifier() throws {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable
                struct Pair {
                    let a = 1, b = 2
                }
                """,
                expandedSource: """
                struct Pair {
                    let a = 1, b = 2
                }

                extension Pair: Equatable {
                    static func == (lhs: Pair, rhs: Pair) -> Bool {
                        return lhs.a == rhs.a && lhs.b == rhs.b
                    }
                }
                """,
                macros: testMacros,
            )
        #endif
    }

    @Test("SkipEquatable excludes whole declaration")
    func skipEquatableExcludesWholeDeclaration() throws {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable
                struct Pair {
                    let id: Int
                    @SkipEquatable let ignored = 1
                }
                """,
                expandedSource: """
                struct Pair {
                    let id: Int
                    let ignored = 1
                }

                extension Pair: Equatable {
                    static func == (lhs: Pair, rhs: Pair) -> Bool {
                        return lhs.id == rhs.id
                    }
                }
                """,
                macros: testMacros,
            )
        #endif
    }

    @Test("SkipEquatable on a multi-binding declaration is diagnosed")
    func skipEquatableOnMultiBindingDeclarationIsDiagnosed() throws {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable
                struct S {
                    let id: Int
                    @SkipEquatable let a = 1, b = 2
                }
                """,
                expandedSource: """
                struct S {
                    let id: Int
                    let a = 1, b = 2
                }

                extension S: Equatable {
                    static func == (lhs: S, rhs: S) -> Bool {
                        return lhs.id == rhs.id
                    }
                }
                """,
                diagnostics: [
                    DiagnosticSpec(message: "peer macro can only be applied to a single variable", line: 4, column: 5),
                ],
                macros: testMacros,
            )
        #endif
    }

    @Test("function-typed properties are excluded")
    func functionTypedPropertiesAreExcluded() throws {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable
                struct Actions {
                    let value: Int
                    let tap: () -> Void
                    let select: @Sendable @MainActor (Int) -> Void
                    let optionalAction: (() -> Void)?
                    let inferred = {}
                }
                """,
                expandedSource: """
                struct Actions {
                    let value: Int
                    let tap: () -> Void
                    let select: @Sendable @MainActor (Int) -> Void
                    let optionalAction: (() -> Void)?
                    let inferred = {}
                }

                extension Actions: Equatable {
                    static func == (lhs: Actions, rhs: Actions) -> Bool {
                        return lhs.value == rhs.value
                    }
                }
                """,
                macros: testMacros,
            )
        #endif
    }

    @Test("@State and environment/reference wrappers are excluded in nonisolated mode")
    func dynamicPropertyWrappersAreExcludedInNonisolatedMode() throws {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable
                struct Panel: View, Equatable {
                    @Environment(\\.accessibilityReduceMotion) private var reduceMotion
                    @State private var count = 0
                    @ScaledMetric private var size = 10
                    @FocusedValue(\\.focusedValue) private var focusedValue
                    @FocusedBinding(\\.focusedBinding) private var focusedBinding
                    @AccessibilityFocusState private var accessibilityFocus: Bool
                    let state: Int

                    var body: some View {
                        Text("\\(state)")
                    }
                }
                """,
                expandedSource: """
                struct Panel: View, Equatable {
                    @Environment(\\.accessibilityReduceMotion) private var reduceMotion
                    @State private var count = 0
                    @ScaledMetric private var size = 10
                    @FocusedValue(\\.focusedValue) private var focusedValue
                    @FocusedBinding(\\.focusedBinding) private var focusedBinding
                    @AccessibilityFocusState private var accessibilityFocus: Bool
                    let state: Int

                    var body: some View {
                        Text("\\(state)")
                    }

                    nonisolated static func == (lhs: Panel, rhs: Panel) -> Bool {
                        return lhs.state == rhs.state
                    }
                }
                """,
                macros: testMacros,
            )
        #endif
    }

    @Test("type containing a function type is diagnosed, not silently dropped")
    func typeContainingFunctionTypeIsDiagnosed() throws {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable
                struct Actions {
                    let value: Int
                    let handlers: [() -> Void]
                }
                """,
                expandedSource: """
                struct Actions {
                    let value: Int
                    let handlers: [() -> Void]
                }
                """,
                diagnostics: [
                    DiagnosticSpec(
                        message: "@Equatable cannot compare a property whose type contains a function type, and silently excluding it would hide stale closure state; mark it with @SkipEquatable to exclude it explicitly",
                        line: 4,
                        column: 9,
                    ),
                ],
                macros: testMacros,
            )
        #endif
    }

    @Test("type containing a function type can be skipped explicitly")
    func typeContainingFunctionTypeCanBeSkippedExplicitly() throws {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable
                struct Actions {
                    let value: Int
                    @SkipEquatable let handlers: [() -> Void]
                }
                """,
                expandedSource: """
                struct Actions {
                    let value: Int
                    let handlers: [() -> Void]
                }

                extension Actions: Equatable {
                    static func == (lhs: Actions, rhs: Actions) -> Bool {
                        return lhs.value == rhs.value
                    }
                }
                """,
                macros: testMacros,
            )
        #endif
    }

    @Test("all inputs excluded warns about always-equal comparison")
    func allInputsExcludedWarnsAboutAlwaysEqualComparison() throws {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable
                struct TapOnly {
                    let onTap: () -> Void
                }
                """,
                expandedSource: """
                struct TapOnly {
                    let onTap: () -> Void
                }

                extension TapOnly: Equatable {
                    static func == (lhs: TapOnly, rhs: TapOnly) -> Bool {
                        return true
                    }
                }
                """,
                diagnostics: [
                    DiagnosticSpec(
                        message: "@Equatable compares no stored properties here (all inputs were excluded); instances always compare equal, so an .equatable()-gated view never re-renders when these inputs change",
                        line: 2,
                        column: 1,
                        severity: .warning,
                    ),
                ],
                macros: testMacros,
            )
        #endif
    }

    @Test("top-level closure initializer is excluded but nested closure initializer is included")
    func topLevelClosureInitializerIsExcludedButNestedClosureInitializerIsIncluded() throws {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable
                struct DerivedRow {
                    let value: Int
                    let derived = makeThing { input in
                        input + 1
                    }
                    let handler = {
                        1
                    }
                }
                """,
                expandedSource: """
                struct DerivedRow {
                    let value: Int
                    let derived = makeThing { input in
                        input + 1
                    }
                    let handler = {
                        1
                    }
                }

                extension DerivedRow: Equatable {
                    static func == (lhs: DerivedRow, rhs: DerivedRow) -> Bool {
                        return lhs.value == rhs.value && lhs.derived == rhs.derived
                    }
                }
                """,
                macros: testMacros,
            )
        #endif
    }

    @Test("typealiased closure is compared (documented limitation)")
    func typealiasedClosureIsCompared() throws {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable
                struct Row {
                    let state: Int
                    let action: Action
                }
                """,
                expandedSource: """
                struct Row {
                    let state: Int
                    let action: Action
                }

                extension Row: Equatable {
                    static func == (lhs: Row, rhs: Row) -> Bool {
                        return lhs.state == rhs.state && lhs.action == rhs.action
                    }
                }
                """,
                macros: testMacros,
            )
        #endif
    }

    @Test("typealiased closure can be skipped explicitly")
    func typealiasedClosureCanBeSkippedExplicitly() throws {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                typealias Action = () -> Void

                @Equatable
                struct Row {
                    let value: Int
                    @SkipEquatable let action: Action
                }
                """,
                expandedSource: """
                typealias Action = () -> Void
                struct Row {
                    let value: Int
                    let action: Action
                }

                extension Row: Equatable {
                    static func == (lhs: Row, rhs: Row) -> Bool {
                        return lhs.value == rhs.value
                    }
                }
                """,
                macros: testMacros,
            )
        #endif
    }

    @Test("generic structs emit conditional conformance")
    func genericStructsEmitConditionalConformance() throws {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable
                struct Box<T> {
                    let value: T
                }
                """,
                expandedSource: """
                struct Box<T> {
                    let value: T
                }

                extension Box: Equatable where T: Equatable {
                    static func == (lhs: Box, rhs: Box) -> Bool {
                        return lhs.value == rhs.value
                    }
                }
                """,
                macros: testMacros,
            )
        #endif
    }

    @Test("generic structs omit unused phantom type parameters from where clause")
    func genericStructsOmitUnusedPhantomTypeParameters() throws {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable
                struct Pair<T, U> {
                    let value: T
                }
                """,
                expandedSource: """
                struct Pair<T, U> {
                    let value: T
                }

                extension Pair: Equatable where T: Equatable {
                    static func == (lhs: Pair, rhs: Pair) -> Bool {
                        return lhs.value == rhs.value
                    }
                }
                """,
                macros: testMacros,
            )
        #endif
    }

    @Test("view-like struct without direct View conformance warns")
    func viewLikeStructWithoutDirectViewConformanceWarns() throws {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable
                struct OrphanView {
                    let value: Int

                    var body: some View {
                        Text("\\(value)")
                    }
                }
                """,
                expandedSource: """
                struct OrphanView {
                    let value: Int

                    var body: some View {
                        Text("\\(value)")
                    }
                }

                extension OrphanView: Equatable {
                    static func == (lhs: OrphanView, rhs: OrphanView) -> Bool {
                        return lhs.value == rhs.value
                    }
                }
                """,
                diagnostics: [
                    DiagnosticSpec(
                        message: "Struct declares `body: some View` without directly conforming to `View`; add `: View` to the struct declaration or use `@Equatable(.nonisolated)` so `.equatable()` can call `==` without actor hops",
                        line: 2,
                        column: 1,
                        severity: .warning,
                    ),
                ],
                macros: testMacros,
            )
        #endif
    }

    @Test("view-like struct with body inside #if warns")
    func viewLikeStructWithConditionalBodyWarns() throws {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable
                struct OrphanView {
                    let value: Int

                    #if os(iOS)
                    var body: some View {
                        Text("\\(value)")
                    }
                    #endif
                }
                """,
                expandedSource: """
                struct OrphanView {
                    let value: Int

                    #if os(iOS)
                    var body: some View {
                        Text("\\(value)")
                    }
                    #endif
                }

                extension OrphanView: Equatable {
                    static func == (lhs: OrphanView, rhs: OrphanView) -> Bool {
                        return lhs.value == rhs.value
                    }
                }
                """,
                diagnostics: [
                    DiagnosticSpec(
                        message: "Struct declares `body: some View` without directly conforming to `View`; add `: View` to the struct declaration or use `@Equatable(.nonisolated)` so `.equatable()` can call `==` without actor hops",
                        line: 2,
                        column: 1,
                        severity: .warning,
                    ),
                ],
                macros: testMacros,
            )
        #endif
    }

    @Test("generic nonisolated member has matching where clauses")
    func genericNonisolatedMemberHasMatchingWhereClauses() throws {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable(.nonisolated)
                struct Box<T> {
                    let value: T
                }
                """,
                expandedSource: """
                struct Box<T> {
                    let value: T

                    nonisolated static func == (lhs: Box, rhs: Box) -> Bool where T: Equatable {
                        return lhs.value == rhs.value
                    }
                }

                extension Box: Equatable where T: Equatable {
                }
                """,
                macros: testMacros,
            )
        #endif
    }

    @Test("public structs get public equality")
    func publicStructsGetPublicEquality() throws {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable
                public struct User {
                    public let id: Int
                }
                """,
                expandedSource: """
                public struct User {
                    public let id: Int
                }

                extension User: Equatable {
                    public static func == (lhs: User, rhs: User) -> Bool {
                        return lhs.id == rhs.id
                    }
                }
                """,
                macros: testMacros,
            )
        #endif
    }

    @Test("non-struct attachments diagnose misuse")
    func nonStructAttachmentsDiagnoseMisuse() throws {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable
                enum Status {}

                @Equatable
                class Box {}

                @Equatable
                actor Worker {}
                """,
                expandedSource: """
                enum Status {}
                class Box {}
                actor Worker {}
                """,
                diagnostics: [
                    DiagnosticSpec(message: "@Equatable can only be attached to a struct", line: 1, column: 1),
                    DiagnosticSpec(message: "@Equatable can only be attached to a struct", line: 4, column: 1),
                    DiagnosticSpec(message: "@Equatable can only be attached to a struct", line: 7, column: 1),
                ],
                macros: testMacros,
            )
        #endif
    }

    @Test("non-identifier property patterns diagnose misuse")
    func nonIdentifierPropertyPatternsDiagnoseMisuse() throws {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable
                struct TupleStorage {
                    let (a, b): (Int, Int)
                }
                """,
                expandedSource: """
                struct TupleStorage {
                    let (a, b): (Int, Int)
                }
                """,
                diagnostics: [
                    DiagnosticSpec(
                        message: "@Equatable only supports simple stored property names",
                        line: 3,
                        column: 9,
                    ),
                ],
                macros: testMacros,
            )
        #endif
    }

    @Test("macro generated equality ignores closures at runtime")
    func generatedEqualityIgnoresClosuresAtRuntime() {
        let first = RuntimeRow(value: 1, action: {})
        let second = RuntimeRow(value: 1, action: { _ = 1 })

        #expect(first == second)
    }

    @Test("macro generated nonisolated equality ignores closures at runtime")
    func generatedNonisolatedEqualityIgnoresClosuresAtRuntime() {
        let first = RuntimeNonisolatedRow(state: 2, action: {})
        let second = RuntimeNonisolatedRow(state: 2, action: { _ = 2 })

        #expect(first == second)
    }

    @Test("macro generated generic equality compiles and compares")
    func generatedGenericEqualityCompilesAndCompares() {
        #expect(RuntimeBox(value: 1) == RuntimeBox(value: 1))
    }

    @Test("macro generated generic nonisolated equality compiles and compares")
    func generatedGenericNonisolatedEqualityCompilesAndCompares() {
        #expect(RuntimeNonisolatedBox(value: 2) == RuntimeNonisolatedBox(value: 2))
    }

    @Test("MainActor default Equatable macro compiles")
    @MainActor
    func mainActorDefaultEquatableMacroCompiles() {
        #expect(RuntimeMainActorModel(value: 1) == RuntimeMainActorModel(value: 1))
    }

    #if canImport(SwiftUI)
        @Test("SwiftUI View can use default Equatable macro with equatable")
        @MainActor
        func swiftUIViewCanUseDefaultEquatableMacroWithEquatable() {
            let view = RuntimeCounterView(value: 1, action: {})

            _ = view.equatable()
        }

        @Test("forced extension SwiftUI View compiles")
        @MainActor
        func forcedExtensionSwiftUIViewCompiles() {
            let view = RuntimeForcedExtensionCounterView(value: 1)

            _ = view.equatable()
        }
    #endif
}

@Equatable
private struct RuntimeRow {
    let value: Int
    let action: () -> Void
}

@Equatable(.nonisolated)
private struct RuntimeNonisolatedRow {
    let state: Int
    let action: () -> Void
}

@Equatable
private struct RuntimeBox<T> {
    let value: T
}

@Equatable(.nonisolated)
private struct RuntimeNonisolatedBox<T> {
    let value: T
}

@MainActor
@Equatable
private struct RuntimeMainActorModel {
    let value: Int
}

#if canImport(SwiftUI)
    import SwiftUI

    @Equatable
    private struct RuntimeCounterView: View {
        let value: Int
        let action: () -> Void

        var body: some View {
            Text(verbatim: "\(value)")
        }
    }

    @Equatable(.extension)
    private struct RuntimeForcedExtensionCounterView: View {
        let value: Int

        var body: some View {
            Text(verbatim: "\(value)")
        }
    }
#endif
