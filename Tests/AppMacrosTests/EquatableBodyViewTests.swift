import AppMacros
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

#if canImport(AppMacrosMacros)
    import AppMacrosMacros

    private let bodyViewMacros: [String: Macro.Type] = [
        "Equatable": EquatableMacro.self,
        "SkipEquatable": SkipEquatableMacro.self,
    ]
#endif

@Suite("EquatableBodyView")
struct EquatableBodyViewTests {
    // A conformer writes `: EquatableBodyView` (not literal View/Equatable). It gets the
    // nonisolated member AND an explicit `extension: Equatable {}` anchor — the member
    // does not witness an *inherited* Equatable conformance without it.
    @Test("conformer: nonisolated member + Equatable anchor")
    func conformerExpansion() throws {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable
                struct ChipView: EquatableBodyView {
                    let title: String
                    let onTap: () -> Void
                    var equatableBody: some View {
                        Text(title)
                    }
                }
                """,
                expandedSource: """
                struct ChipView: EquatableBodyView {
                    let title: String
                    let onTap: () -> Void
                    var equatableBody: some View {
                        Text(title)
                    }

                    nonisolated static func == (lhs: ChipView, rhs: ChipView) -> Bool {
                        return lhs.title == rhs.title
                    }
                }

                extension ChipView: Equatable {
                }
                """,
                macros: bodyViewMacros,
            )
        #endif
    }

    @Test("forbids @StateObject / @ObservedObject / @Binding")
    func forbidsDynamicProperty() throws {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable
                struct Panel: EquatableBodyView {
                    @StateObject var model: Model
                    let title: String
                    var equatableBody: some View {
                        Text(title)
                    }
                }
                """,
                expandedSource: """
                struct Panel: EquatableBodyView {
                    @StateObject var model: Model
                    let title: String
                    var equatableBody: some View {
                        Text(title)
                    }

                    nonisolated static func == (lhs: Panel, rhs: Panel) -> Bool {
                        return lhs.title == rhs.title
                    }
                }

                extension Panel: Equatable {
                }
                """,
                diagnostics: [
                    DiagnosticSpec(
                        message: "@EquatableBodyView cannot compare @StateObject / @ObservedObject / @Binding (not Equatable → stale); hoist state to a parent and pass value props",
                        line: 3,
                        column: 5,
                    ),
                ],
                macros: bodyViewMacros,
            )
        #endif
    }

    @Test("forbids a direct body declaration")
    func forbidsDirectBody() throws {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable
                struct Panel: EquatableBodyView {
                    let title: String
                    var body: some View {
                        Text(title)
                    }
                }
                """,
                expandedSource: """
                struct Panel: EquatableBodyView {
                    let title: String
                    var body: some View {
                        Text(title)
                    }

                    nonisolated static func == (lhs: Panel, rhs: Panel) -> Bool {
                        return lhs.title == rhs.title
                    }
                }

                extension Panel: Equatable {
                }
                """,
                diagnostics: [
                    DiagnosticSpec(
                        message: "@EquatableBodyView must not declare `body` directly (it bypasses the baked-in .equatable() gate); put the content in `equatableBody`",
                        line: 4,
                        column: 5,
                        fixIts: [
                            FixItSpec(message: "rename `body` to `equatableBody`"),
                        ],
                    ),
                ],
                macros: bodyViewMacros,
                applyFixIts: ["rename `body` to `equatableBody`"],
                fixedSource: """
                @Equatable
                struct Panel: EquatableBodyView {
                    let title: String
                    var equatableBody: some View {
                        Text(title)
                    }
                }
                """,
            )
        #endif
    }

    // #5: a protocol-composition conformance is detected (nonisolated member, and
    // no redundant `: Equatable` extension since Equatable is written directly).
    @Test("protocol composition View & Equatable is detected")
    func compositionConformance() throws {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable
                struct Row: View & Equatable {
                    let title: String
                    var body: some View {
                        Text(title)
                    }
                }
                """,
                expandedSource: """
                struct Row: View & Equatable {
                    let title: String
                    var body: some View {
                        Text(title)
                    }

                    nonisolated static func == (lhs: Row, rhs: Row) -> Bool {
                        return lhs.title == rhs.title
                    }
                }
                """,
                macros: bodyViewMacros,
            )
        #endif
    }

    // #2: a `body` hidden inside `#if` is still diagnosed (the diagnostics recurse
    // into conditional-compilation blocks).
    @Test("forbids a body declared inside #if")
    func forbidsConditionalBody() throws {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable
                struct Panel: EquatableBodyView {
                    let title: String
                    #if os(iOS)
                    var body: some View {
                        Text(title)
                    }
                    #endif
                }
                """,
                expandedSource: """
                struct Panel: EquatableBodyView {
                    let title: String
                    #if os(iOS)
                    var body: some View {
                        Text(title)
                    }
                    #endif

                    nonisolated static func == (lhs: Panel, rhs: Panel) -> Bool {
                        return lhs.title == rhs.title
                    }
                }

                extension Panel: Equatable {
                }
                """,
                diagnostics: [
                    DiagnosticSpec(
                        message: "@EquatableBodyView must not declare `body` directly (it bypasses the baked-in .equatable() gate); put the content in `equatableBody`",
                        line: 5,
                        column: 5,
                        fixIts: [
                            FixItSpec(message: "rename `body` to `equatableBody`"),
                        ],
                    ),
                ],
                macros: bodyViewMacros,
            )
        #endif
    }
}

#if canImport(SwiftUI)
    import SwiftUI

    // Real conformer: proves the macro output + the EquatableBodyView default body +
    // _EquatableHost all compile together and the generated == ignores the closure.
    @Equatable
    private struct RuntimeChipView: EquatableBodyView {
        let title: String
        let onTap: () -> Void

        var equatableBody: some View {
            Text(verbatim: title)
        }
    }

    // A directly-declared `: View, Equatable` (a common convention). Proves the
    // macro's nonisolated member witnesses a directly-written Equatable conformance.
    @Equatable
    private struct RuntimeDirectEqView: View, Equatable {
        let value: Int

        var body: some View {
            Text(verbatim: "\(value)")
        }
    }

    // #1: a View holding @State must COMPILE — the generated nonisolated == reads the
    // @State value (proves @State is compared, not excluded).
    @Equatable
    private struct RuntimeStatefulView: View {
        @State private var count = 0
        let title: String

        var body: some View {
            Text(verbatim: "\(title)\(count)")
        }
    }

    @Equatable
    private struct RuntimeStateComparedView: View {
        @State private var count: Int
        let title: String

        init(title: String, count: Int) {
            self.title = title
            _count = State(initialValue: count)
        }

        var body: some View {
            Text(verbatim: "\(title)\(count)")
        }
    }

    // #5: protocol-composition conformance compiles end to end.
    @Equatable
    private struct RuntimeCompositionView: View & Equatable {
        let value: Int

        var body: some View {
            Text(verbatim: "\(value)")
        }
    }

    @Suite("EquatableBodyView runtime")
    @MainActor
    struct EquatableBodyViewRuntimeTests {
        @Test("default body compiles and equality ignores the closure")
        func compilesAndCompares() {
            let view = RuntimeChipView(title: "x", onTap: {})
            _ = view.body
            #expect(view == RuntimeChipView(title: "x", onTap: { _ = 1 }))
            #expect(view != RuntimeChipView(title: "y", onTap: {}))
        }

        @Test("@State view and composition view compile and compare")
        func stateAndCompositionCompile() {
            #expect(RuntimeStatefulView(title: "a") == RuntimeStatefulView(title: "a"))
            #expect(RuntimeCompositionView(value: 1) != RuntimeCompositionView(value: 2))
        }

        @Test("@State value is included in generated equality")
        func stateValueIsCompared() {
            #expect(RuntimeStateComparedView(title: "a", count: 1) == RuntimeStateComparedView(title: "a", count: 1))
            #expect(RuntimeStateComparedView(title: "a", count: 1) != RuntimeStateComparedView(title: "a", count: 2))
        }
    }
#endif
