import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

enum EquatableDiagnostic: String, DiagnosticMessage {
    case onlyStruct
    case unsupportedPattern
    case conditionalStoredProperty
    case compositeFunctionType
    case noComparedProperties
    case equatableBodyViewForbiddenDynamicProperty
    case equatableBodyViewDirectBody
    case viewLikeStructNeedsIsolation
    case existingEquality
    case unsupportedExpansion

    var message: String {
        switch self {
        case .onlyStruct:
            "@Equatable can only be attached to a struct"
        case .unsupportedPattern:
            "@Equatable only supports simple stored property names"
        case .conditionalStoredProperty:
            "@Equatable does not compare stored properties declared inside #if — the generated == would silently ignore platform-specific changes (stale view); mark it with @SkipEquatable to exclude it explicitly, or declare it unconditionally"
        case .compositeFunctionType:
            "@Equatable cannot compare a property whose type contains a function type, and silently excluding it would hide stale closure state; mark it with @SkipEquatable to exclude it explicitly"
        case .noComparedProperties:
            "@Equatable compares no stored properties here (all inputs were excluded); instances always compare equal, so an .equatable()-gated view never re-renders when these inputs change"
        case .equatableBodyViewForbiddenDynamicProperty:
            "EquatableBodyView cannot compare @ObservedObject / @Bindable / @Binding (parent-swappable source, not Equatable → stale); hoist state to a parent and pass value props"
        case .equatableBodyViewDirectBody:
            "EquatableBodyView must not declare `body` directly (it bypasses the baked-in .equatable() gate); put the content in `equatableBody`"
        case .viewLikeStructNeedsIsolation:
            "Struct declares `body: some View` without a direct View conformance; declare `: View` or choose @Equatable(.mainActor) / @Equatable(.nonisolated) explicitly"
        case .existingEquality:
            "@Equatable generates `==`; remove the hand-written equality operator or remove @Equatable"
        case .unsupportedExpansion:
            "@Equatable requires a literal .mainActor, .nonisolated, .extension, or nil expansion argument"
        }
    }

    var diagnosticID: MessageID {
        MessageID(domain: "AppMacros.Equatable", id: rawValue)
    }

    var severity: DiagnosticSeverity {
        switch self {
        case .viewLikeStructNeedsIsolation, .noComparedProperties: .warning
        default: .error
        }
    }
}

struct EquatableIsolationDiagnostic: DiagnosticMessage {
    let protocolName: String
    let isolation: String

    var message: String {
        "@Equatable requires `\(isolation) \(protocolName)` to match the generated equality; annotate this conformance explicitly"
    }

    var diagnosticID: MessageID {
        MessageID(domain: "AppMacros.Equatable", id: "conformanceIsolation")
    }

    var severity: DiagnosticSeverity {
        .error
    }

    func diagnostic(for type: TypeSyntax) -> Diagnostic {
        let base = type.as(AttributedTypeSyntax.self)?.baseType ?? type
        let replacement: TypeSyntax = "\(raw: isolation) \(base.trimmed)"
        let formatted = replacement.with(\.leadingTrivia, type.leadingTrivia)
            .with(\.trailingTrivia, type.trailingTrivia)
        return Diagnostic(
            node: Syntax(type),
            message: self,
            fixIts: [FixIt(
                message: MacroExpansionFixItMessage("use \(isolation) \(protocolName)"),
                changes: [.replace(oldNode: Syntax(type), newNode: Syntax(formatted))],
            )],
        )
    }
}
