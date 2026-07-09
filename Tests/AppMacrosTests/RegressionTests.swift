import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

#if canImport(AppMacrosMacros)
    import AppMacrosMacros

    private let verifyMacros: [String: Macro.Type] = [
        "Equatable": EquatableMacro.self,
        "SkipEquatable": SkipEquatableMacro.self,
    ]
#endif

/// Regression coverage for the structural-review findings (F2-F4, F8, F9).
@Suite("Verified Findings Regression")
struct RegressionTests {
    // F3: lazy vars are not stable stored comparison inputs and must be excluded.
    @Test("lazy var exclusion")
    func lazyVar() throws {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable
                struct S {
                    let id: Int
                    lazy var cache = 1
                }
                """,
                expandedSource: """
                struct S {
                    let id: Int
                    lazy var cache = 1
                }

                extension S: Equatable {
                    static func == (lhs: S, rhs: S) -> Bool {
                        return lhs.id == rhs.id
                    }
                }
                """,
                macros: verifyMacros,
            )
        #endif
    }

    // F4: closure exclusion is syntactic — a closure hidden behind a typealias is
    // still compared (documented limitation). Use @SkipEquatable to exclude it.
    @Test("typealiased closure is compared (documented limitation)")
    func typealiasClosure() throws {
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
                macros: verifyMacros,
            )
        #endif
    }

    // F4: the documented escape hatch — @SkipEquatable excludes the typealiased closure.
    @Test("SkipEquatable excludes a typealiased closure")
    func typealiasClosureSkipped() throws {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable
                struct Row {
                    let state: Int
                    @SkipEquatable let action: Action
                }
                """,
                expandedSource: """
                struct Row {
                    let state: Int
                    let action: Action
                }

                extension Row: Equatable {
                    static func == (lhs: Row, rhs: Row) -> Bool {
                        return lhs.state == rhs.state
                    }
                }
                """,
                macros: verifyMacros,
            )
        #endif
    }

    // F9: generic structs need a conditional Equatable conformance.
    @Test("generic struct where clause")
    func genericStruct() throws {
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
                macros: verifyMacros,
            )
        #endif
    }

    // F8: only a top-level closure literal initializer is closure state; a closure
    // nested inside a call is not, so the property must still be compared.
    @Test("nested closure initializer is included")
    func closureInitOverMatch() throws {
        #if canImport(AppMacrosMacros)
            assertMacroExpansion(
                """
                @Equatable
                struct M {
                    let a: Int
                    let derived = makeThing { $0 + 1 }
                }
                """,
                expandedSource: """
                struct M {
                    let a: Int
                    let derived = makeThing { $0 + 1 }
                }

                extension M: Equatable {
                    static func == (lhs: M, rhs: M) -> Bool {
                        return lhs.a == rhs.a && lhs.derived == rhs.derived
                    }
                }
                """,
                macros: verifyMacros,
            )
        #endif
    }

    // F2: @SkipEquatable applies to one binding; multi-binding declarations must be split.
    @Test("skip equatable multibinding is diagnosed")
    func skipMultiBinding() throws {
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
                macros: verifyMacros,
            )
        #endif
    }
}
