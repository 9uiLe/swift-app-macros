import AppMacros
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@Suite("Equatable Macro")
struct EquatableMacroTests {
    @Test
    func `non-View default emits extension conformance`() {
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

    @Test
    func `View equality uses MainActor`() {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable
                struct CounterView: View, @MainActor Equatable {
                    let value: Int
                    let action: @MainActor () -> Void

                    var body: some View {
                        Text("\\(value)")
                    }
                }
                """,
                expandedSource: """
                struct CounterView: View, @MainActor Equatable {
                    let value: Int
                    let action: @MainActor () -> Void

                    var body: some View {
                        Text("\\(value)")
                    }

                    @MainActor static func == (lhs: CounterView, rhs: CounterView) -> Bool {
                        return lhs.value == rhs.value
                    }
                }
                """,
                macros: testMacros,
            )
        #endif
    }

    @Test
    func `View default adds Equatable conformance when missing`() {
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

                    @MainActor static func == (lhs: CounterView, rhs: CounterView) -> Bool {
                        return lhs.value == rhs.value
                    }
                }

                extension CounterView: @MainActor Equatable {
                }
                """,
                macros: testMacros,
            )
        #endif
    }

    @Test
    func `explicit nonisolated emits member for non-View`() {
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

    @Test
    func `explicit extension can be forced on View`() {
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

                extension CounterView: @MainActor Equatable {
                    @MainActor static func == (lhs: CounterView, rhs: CounterView) -> Bool {
                        return lhs.value == rhs.value
                    }
                }
                """,
                macros: testMacros,
            )
        #endif
    }

    @Test
    func `MainActor type has MainActor equality and conformance`() {
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

                    @MainActor static func == (lhs: Model, rhs: Model) -> Bool {
                        return lhs.value == rhs.value
                    }
                }

                extension Model: @MainActor Equatable {
                }
                """,
                macros: testMacros,
            )
        #endif
    }

    @Test
    func `generic structs emit conditional conformance`() {
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

    @Test
    func `generic structs omit unused phantom type parameters from where clause`() {
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

    @Test
    func `view-like struct without direct View conformance warns`() {
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
                        message: "Struct declares `body: some View` without a direct View conformance; declare `: View` or choose @Equatable(.mainActor) / @Equatable(.nonisolated) explicitly",
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
    func `view-like struct with body inside #if warns`() {
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
                        message: "Struct declares `body: some View` without a direct View conformance; declare `: View` or choose @Equatable(.mainActor) / @Equatable(.nonisolated) explicitly",
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
    func `generic nonisolated member has matching where clauses`() {
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

    @Test
    func `public structs get public equality`() {
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

    @Test
    func `non-struct attachments diagnose misuse`() {
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

    @Test
    func `non-identifier property patterns diagnose misuse`() {
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
}
