import AppMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@Suite("Equatable properties")
struct EquatablePropertyTests {
    @Test
    func `a hand-written equality witness is diagnosed before generating a duplicate`() {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable
                struct Row {
                    let value: Int
                    static func == (lhs: Self, rhs: Self) -> Bool { true }
                }
                """,
                expandedSource: """
                struct Row {
                    let value: Int
                    static func == (lhs: Self, rhs: Self) -> Bool { true }
                }
                """,
                diagnostics: [DiagnosticSpec(
                    message: "@Equatable generates `==`; remove the hand-written equality operator or remove @Equatable",
                    line: 4, column: 5,
                )],
                macros: testMacros,
            )
        #endif
    }

    @Test
    func `SwiftUI storage is excluded even without visible View isolation`() {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable
                struct Row {
                    let title: String
                    @State var count = 0
                    #if os(iOS)
                    @Environment(\\.colorScheme) var colorScheme
                    #endif
                }
                """,
                expandedSource: """
                struct Row {
                    let title: String
                    @State var count = 0
                    #if os(iOS)
                    @Environment(\\.colorScheme) var colorScheme
                    #endif
                }

                extension Row: Equatable {
                    static func == (lhs: Row, rhs: Row) -> Bool {
                        return lhs.title == rhs.title
                    }
                }
                """,
                macros: testMacros,
            )
        #endif
    }

    @Test
    func `empty struct compares true`() {
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

    @Test
    func `lazy properties are excluded`() {
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

    @Test
    func `computed and static properties are excluded`() {
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

    @Test
    func `stored properties with observers are included`() {
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

    @Test
    func `stored property inside #if produces an error without generated equality`() {
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

    @Test
    func `stored property inside #if can be skipped explicitly`() {
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

    @Test
    func `multi-binding vars compare every identifier`() {
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

    @Test
    func `SkipEquatable excludes whole declaration`() {
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

    @Test
    func `SkipEquatable on a multi-binding declaration is diagnosed`() {
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

    @Test
    func `function-typed properties are excluded`() {
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

    @Test
    func `SwiftUI wrappers are excluded from MainActor equality`() {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable
                struct Panel: View, @MainActor Equatable {
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
                struct Panel: View, @MainActor Equatable {
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

                    @MainActor static func == (lhs: Panel, rhs: Panel) -> Bool {
                        return lhs.state == rhs.state
                    }
                }
                """,
                macros: testMacros,
            )
        #endif
    }

    @Test
    func `type containing a function type produces an error without generated equality`() {
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

    @Test
    func `type containing a function type can be skipped explicitly`() {
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

    @Test
    func `all inputs excluded warns about always-equal comparison`() {
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

    @Test
    func `top-level closure initializer is excluded but nested closure initializer is included`() {
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

    @Test
    func `typealiased closure requires an explicit exclusion`() {
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

    @Test
    func `typealiased closure can be skipped explicitly`() {
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
}
