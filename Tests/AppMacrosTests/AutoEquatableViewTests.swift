import AppMacros
import SwiftSyntaxMacrosTestSupport
import SwiftUI
import Testing

@AutoEquatableView
private struct StaticTitle: View {
    let title: String
    @Environment(\.colorScheme) private var scheme

    var equatableBody: some View {
        Text(title).foregroundStyle(scheme == .dark ? .white : .black)
    }
}

@AutoEquatableView
private struct ActionTitle: View {
    let title: String
    let action: () -> Void

    var equatableBody: some View {
        Button(title, action: action)
    }
}

@AutoEquatableView
private struct BoundToggle: View {
    @Binding var isOn: Bool

    var equatableBody: some View {
        Toggle("Updates", isOn: $isOn)
    }
}

@AutoEquatableView
private struct ArbitraryContent<Content: View>: View {
    @SkipEquatable let content: Content

    var equatableBody: some View {
        content
    }
}

@Suite("AutoEquatableView")
@MainActor
struct AutoEquatableViewTests {
    @Test
    func `comparable inputs generate equality while Environment remains SwiftUI-managed`() {
        #expect(StaticTitle(title: "A") == StaticTitle(title: "A"))
        #expect(StaticTitle(title: "A") != StaticTitle(title: "B"))
        _ = StaticTitle(title: "A").body
    }

    @Test
    func `actions bindings and arbitrary content retain an ordinary View body`() {
        _ = ActionTitle(title: "Save", action: {}).body
        _ = BoundToggle(isOn: .constant(true)).body
        _ = ArbitraryContent(content: Text("Child")).body
    }

    @Test
    func `closure input avoids an equality boundary in expansion`() {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @AutoEquatableView
                struct ActionTitle: View {
                    let title: String
                    let action: () -> Void
                    var equatableBody: some View { Button(title, action: action) }
                }
                """,
                expandedSource: """
                struct ActionTitle: View {
                    let title: String
                    let action: () -> Void
                    var equatableBody: some View { Button(title, action: action) }

                    var body: some View {
                        equatableBody
                    }
                }
                """,
                macros: testMacros,
            )
        #endif
    }

    @Test
    func `comparable input adds isolated equality and a baked-in boundary`() {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @AutoEquatableView
                struct StaticTitle: View {
                    let title: String
                    @Environment(\\.colorScheme) var scheme
                    var equatableBody: some View { Text(title) }
                }
                """,
                expandedSource: """
                struct StaticTitle: View {
                    let title: String
                    @Environment(\\.colorScheme) var scheme
                    var equatableBody: some View { Text(title) }

                    @MainActor static func == (lhs: StaticTitle, rhs: StaticTitle) -> Bool {
                        return lhs.title == rhs.title
                    }
                }

                extension StaticTitle: @MainActor EquatableBodyView {
                }

                extension StaticTitle: @MainActor Equatable {
                }
                """,
                macros: testMacros,
            )
        #endif
    }

    @Test
    func `a directly declared body is rejected before expansion`() {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @AutoEquatableView
                struct Title: View {
                    let title: String
                    var body: some View { Text(title) }
                }
                """,
                expandedSource: """
                struct Title: View {
                    let title: String
                    var body: some View { Text(title) }
                }
                """,
                diagnostics: [DiagnosticSpec(
                    message: "@AutoEquatableView generates body; implement equatableBody instead",
                    line: 2, column: 1,
                )],
                macros: testMacros,
            )
        #endif
    }

    @Test
    func `a missing equatableBody is diagnosed before expansion`() {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @AutoEquatableView
                struct Title: View {
                    let title: String
                }
                """,
                expandedSource: """
                struct Title: View {
                    let title: String
                }
                """,
                diagnostics: [DiagnosticSpec(
                    message: "@AutoEquatableView requires `var equatableBody: some View`",
                    line: 2, column: 1,
                )],
                macros: testMacros,
            )
        #endif
    }
}
