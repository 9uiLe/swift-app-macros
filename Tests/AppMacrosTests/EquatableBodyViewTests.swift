import AppMacros
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@Suite("EquatableBodyView")
struct EquatableBodyViewTests {
    @Test
    func `EquatableBodyView conformer has MainActor equality and an explicit Equatable conformance`() {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable
                struct ChipView: @MainActor EquatableBodyView {
                    let title: String
                    let onTap: () -> Void
                    var equatableBody: some View {
                        Text(title)
                    }
                }
                """,
                expandedSource: """
                struct ChipView: @MainActor EquatableBodyView {
                    let title: String
                    let onTap: () -> Void
                    var equatableBody: some View {
                        Text(title)
                    }

                    @MainActor static func == (lhs: ChipView, rhs: ChipView) -> Bool {
                        return lhs.title == rhs.title
                    }
                }

                extension ChipView: @MainActor Equatable {
                }
                """,
                macros: testMacros,
            )
        #endif
    }

    @Test
    func `forbids parent-swappable sources: @ObservedObject / @Bindable / @Binding`() {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable
                struct Panel: @MainActor EquatableBodyView {
                    @ObservedObject var model: Model
                    @Bindable var draft: Draft
                    let title: String
                    var equatableBody: some View {
                        Text(title)
                    }
                }
                """,
                expandedSource: """
                struct Panel: @MainActor EquatableBodyView {
                    @ObservedObject var model: Model
                    @Bindable var draft: Draft
                    let title: String
                    var equatableBody: some View {
                        Text(title)
                    }
                }
                """,
                diagnostics: [
                    DiagnosticSpec(
                        message: "EquatableBodyView cannot compare @ObservedObject / @Bindable / @Binding (parent-swappable source, not Equatable → stale); hoist state to a parent and pass value props",
                        line: 3,
                        column: 5,
                    ),
                    DiagnosticSpec(
                        message: "EquatableBodyView cannot compare @ObservedObject / @Bindable / @Binding (parent-swappable source, not Equatable → stale); hoist state to a parent and pass value props",
                        line: 4,
                        column: 5,
                    ),
                ],
                macros: testMacros,
            )
        #endif
    }

    @Test
    func `allows @StateObject as owned state, excluded from equality`() {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable
                struct Panel: @MainActor EquatableBodyView {
                    @StateObject private var model = Model()
                    let title: String
                    var equatableBody: some View {
                        Text(title)
                    }
                }
                """,
                expandedSource: """
                struct Panel: @MainActor EquatableBodyView {
                    @StateObject private var model = Model()
                    let title: String
                    var equatableBody: some View {
                        Text(title)
                    }

                    @MainActor static func == (lhs: Panel, rhs: Panel) -> Bool {
                        return lhs.title == rhs.title
                    }
                }

                extension Panel: @MainActor Equatable {
                }
                """,
                macros: testMacros,
            )
        #endif
    }

    @Test
    func `forbids a direct body declaration`() {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable
                struct Panel: @MainActor EquatableBodyView {
                    let title: String
                    var body: some View {
                        Text(title)
                    }
                }
                """,
                expandedSource: """
                struct Panel: @MainActor EquatableBodyView {
                    let title: String
                    var body: some View {
                        Text(title)
                    }
                }
                """,
                diagnostics: [
                    DiagnosticSpec(
                        message: "EquatableBodyView must not declare `body` directly (it bypasses the baked-in .equatable() gate); put the content in `equatableBody`",
                        line: 4,
                        column: 5,
                        fixIts: [
                            FixItSpec(message: "rename `body` to `equatableBody`"),
                        ],
                    ),
                ],
                macros: testMacros,
                applyFixIts: ["rename `body` to `equatableBody`"],
                fixedSource: """
                @Equatable
                struct Panel: @MainActor EquatableBodyView {
                    let title: String
                    var equatableBody: some View {
                        Text(title)
                    }
                }
                """,
            )
        #endif
    }

    @Test
    func `protocol composition @MainActor View & Equatable gets MainActor == without a redundant Equatable extension`() {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable
                struct Row: @MainActor View & Equatable {
                    let title: String
                    var body: some View {
                        Text(title)
                    }
                }
                """,
                expandedSource: """
                struct Row: @MainActor View & Equatable {
                    let title: String
                    var body: some View {
                        Text(title)
                    }

                    @MainActor static func == (lhs: Row, rhs: Row) -> Bool {
                        return lhs.title == rhs.title
                    }
                }
                """,
                macros: testMacros,
            )
        #endif
    }

    @Test
    func `forbids a body declared inside #if`() {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable
                struct Panel: @MainActor EquatableBodyView {
                    let title: String
                    #if os(iOS)
                    var body: some View {
                        Text(title)
                    }
                    #endif
                }
                """,
                expandedSource: """
                struct Panel: @MainActor EquatableBodyView {
                    let title: String
                    #if os(iOS)
                    var body: some View {
                        Text(title)
                    }
                    #endif
                }
                """,
                diagnostics: [
                    DiagnosticSpec(
                        message: "EquatableBodyView must not declare `body` directly (it bypasses the baked-in .equatable() gate); put the content in `equatableBody`",
                        line: 5,
                        column: 5,
                        fixIts: [
                            FixItSpec(message: "rename `body` to `equatableBody`"),
                        ],
                    ),
                ],
                macros: testMacros,
            )
        #endif
    }
}

#if canImport(SwiftUI)
    import SwiftUI

    @Equatable
    private struct RuntimeChipView: @MainActor EquatableBodyView {
        let title: String
        let onTap: () -> Void

        var equatableBody: some View {
            Text(verbatim: title)
        }
    }

    @Equatable
    private struct RuntimeDirectEqView: View, @MainActor Equatable {
        let value: Int

        var body: some View {
            Text(verbatim: "\(value)")
        }
    }

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

    @Equatable
    private struct RuntimeCompositionView: @MainActor View & Equatable {
        let value: Int

        var body: some View {
            Text(verbatim: "\(value)")
        }
    }

    @Suite("EquatableBodyView runtime")
    @MainActor
    struct EquatableBodyViewRuntimeTests {
        @Test
        func `default body compiles and equality ignores the closure`() {
            let view = RuntimeChipView(title: "x", onTap: {})
            _ = view.body
            #expect(view == RuntimeChipView(title: "x", onTap: { _ = 1 }))
            #expect(view != RuntimeChipView(title: "y", onTap: {}))
        }

        @Test
        func `@State view and composition view compile and compare`() {
            #expect(RuntimeStatefulView(title: "a") == RuntimeStatefulView(title: "a"))
            #expect(RuntimeCompositionView(value: 1) != RuntimeCompositionView(value: 2))
        }

        @Test
        func `@State value is excluded from generated equality`() {
            #expect(RuntimeStateComparedView(title: "a", count: 1) == RuntimeStateComparedView(title: "a", count: 2))
            #expect(RuntimeStateComparedView(title: "a", count: 1) != RuntimeStateComparedView(title: "b", count: 1))
        }

        @Test
        func `directly-written Equatable conformance is witnessed by the generated MainActor ==`() {
            #expect(RuntimeDirectEqView(value: 1) == RuntimeDirectEqView(value: 1))
            #expect(RuntimeDirectEqView(value: 1) != RuntimeDirectEqView(value: 2))
        }
    }
#endif
