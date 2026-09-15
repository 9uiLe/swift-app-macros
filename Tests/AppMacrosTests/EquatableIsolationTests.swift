import AppMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@Suite("Equatable isolation")
struct EquatableIsolationTests {
    @Test
    func `computed expansion arguments produce an error without generated equality`() {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable(expansion)
                struct Row {
                    let value: Int
                }
                """,
                expandedSource: """
                struct Row {
                    let value: Int
                }
                """,
                diagnostics: [DiagnosticSpec(
                    message: "@Equatable requires a literal .mainActor, .nonisolated, .extension, or nil expansion argument",
                    line: 1, column: 1,
                )],
                macros: testMacros,
            )
        #endif
    }

    @Test
    func `preconcurrency is not mistaken for a global actor`() {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable
                struct Row: View, @preconcurrency Equatable {
                    let title: String
                }
                """,
                expandedSource: """
                struct Row: View, @preconcurrency Equatable {
                    let title: String
                }
                """,
                diagnostics: [DiagnosticSpec(
                    message: "@Equatable requires `@MainActor Equatable` to match the generated equality; annotate this conformance explicitly",
                    line: 2, column: 19,
                    fixIts: [FixItSpec(message: "use @MainActor Equatable")],
                )],
                macros: testMacros,
                applyFixIts: ["use @MainActor Equatable"],
                fixedSource: """
                @Equatable
                struct Row: View, @MainActor Equatable {
                    let title: String
                }
                """,
            )
        #endif
    }

    @Test
    func `direct Equatable conformance gets an actionable isolation fix`() {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable
                struct Row: View, Equatable {
                    let title: String
                }
                """,
                expandedSource: """
                struct Row: View, Equatable {
                    let title: String
                }
                """,
                diagnostics: [DiagnosticSpec(
                    message: "@Equatable requires `@MainActor Equatable` to match the generated equality; annotate this conformance explicitly",
                    line: 2, column: 19,
                    fixIts: [FixItSpec(message: "use @MainActor Equatable")],
                )],
                macros: testMacros,
                applyFixIts: ["use @MainActor Equatable"],
                fixedSource: """
                @Equatable
                struct Row: View, @MainActor Equatable {
                    let title: String
                }
                """,
            )
        #endif
    }

    @Test
    func `EquatableBodyView conformance gets an actionable isolation fix`() {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable
                struct Row: EquatableBodyView {
                    let title: String
                }
                """,
                expandedSource: """
                struct Row: EquatableBodyView {
                    let title: String
                }
                """,
                diagnostics: [DiagnosticSpec(
                    message: "@Equatable requires `@MainActor EquatableBodyView` to match the generated equality; annotate this conformance explicitly",
                    line: 2, column: 13,
                    fixIts: [FixItSpec(message: "use @MainActor EquatableBodyView")],
                )],
                macros: testMacros,
                applyFixIts: ["use @MainActor EquatableBodyView"],
                fixedSource: """
                @Equatable
                struct Row: @MainActor EquatableBodyView {
                    let title: String
                }
                """,
            )
        #endif
    }

    @Test
    func `explicit MainActor mode supports types whose isolation is not visible to the macro`() {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable(.mainActor)
                public struct Row {
                    let title: String
                }
                """,
                expandedSource: """
                public struct Row {
                    let title: String

                    @MainActor public static func == (lhs: Row, rhs: Row) -> Bool {
                        return lhs.title == rhs.title
                    }
                }

                extension Row: @MainActor Equatable {
                }
                """,
                macros: testMacros,
            )
        #endif
    }

    @Test
    func `nonisolated View has nonisolated equality and excludes SwiftUI storage`() {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable
                nonisolated struct Row: View {
                    let title: String
                    @State var count = 0
                }
                """,
                expandedSource: """
                nonisolated struct Row: View {
                    let title: String
                    @State var count = 0

                    nonisolated static func == (lhs: Row, rhs: Row) -> Bool {
                        return lhs.title == rhs.title
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
    func `explicit nonisolated mode uses a directly declared Equatable conformance`() {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable(.nonisolated)
                struct Row: View, Equatable {
                    let title: String
                }
                """,
                expandedSource: """
                struct Row: View, Equatable {
                    let title: String

                    nonisolated static func == (lhs: Row, rhs: Row) -> Bool {
                        return lhs.title == rhs.title
                    }
                }
                """,
                macros: testMacros,
            )
        #endif
    }

    @Test
    func `equality and conformance use the custom global actor`() {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @RenderActor
                @Equatable
                struct Frame {
                    let value: Int
                }
                """,
                expandedSource: """
                @RenderActor
                struct Frame {
                    let value: Int

                    @RenderActor static func == (lhs: Frame, rhs: Frame) -> Bool {
                        return lhs.value == rhs.value
                    }
                }

                extension Frame: @RenderActor Equatable {
                }
                """,
                macros: testMacros,
            )
        #endif
    }

    @Test
    func `qualified actor and protocol names do not duplicate Equatable conformance`() {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable
                struct Row: SwiftUI.View, @_Concurrency.MainActor Swift.Equatable {
                    let title: String
                }
                """,
                expandedSource: """
                struct Row: SwiftUI.View, @_Concurrency.MainActor Swift.Equatable {
                    let title: String

                    @_Concurrency.MainActor static func == (lhs: Row, rhs: Row) -> Bool {
                        return lhs.title == rhs.title
                    }
                }
                """,
                macros: testMacros,
            )
        #endif
    }

    @Test
    func `nonisolated mode diagnoses an incompatible isolated conformance`() {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable(.nonisolated)
                struct Row: View, @MainActor Equatable {
                    let title: String
                }
                """,
                expandedSource: """
                struct Row: View, @MainActor Equatable {
                    let title: String
                }
                """,
                diagnostics: [DiagnosticSpec(
                    message: "@Equatable requires `nonisolated Equatable` to match the generated equality; annotate this conformance explicitly",
                    line: 2, column: 19,
                    fixIts: [FixItSpec(message: "use nonisolated Equatable")],
                )],
                macros: testMacros,
                applyFixIts: ["use nonisolated Equatable"],
                fixedSource: """
                @Equatable(.nonisolated)
                struct Row: View, nonisolated Equatable {
                    let title: String
                }
                """,
            )
        #endif
    }
}
