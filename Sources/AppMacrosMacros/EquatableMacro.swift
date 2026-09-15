import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

public struct EquatableMacro: MemberMacro, ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo _: [TypeSyntax],
        in _: some MacroExpansionContext,
    ) throws -> [DeclSyntax] {
        guard let declaration = declaration.as(StructDeclSyntax.self) else {
            return []
        }
        let expansion = EquatableExpansionPlan(attribute: node, declaration: declaration)
        guard expansion.isValid, expansion.placement == .member else {
            return []
        }
        return [expansion.equalityFunction(for: declaration.name.trimmedDescription)]
    }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo _: [TypeSyntax],
        in context: some MacroExpansionContext,
    ) throws -> [ExtensionDeclSyntax] {
        guard let declaration = declaration.as(StructDeclSyntax.self) else {
            context.diagnose(Diagnostic(node: Syntax(declaration), message: EquatableDiagnostic.onlyStruct))
            return []
        }
        let expansion = EquatableExpansionPlan(attribute: node, declaration: declaration)
        // Both macro roles run independently; emitting here avoids duplicate diagnostics.
        expansion.diagnostics.forEach(context.diagnose)
        guard expansion.isValid else {
            return []
        }
        return try expansion.extensions(for: type)
    }
}

public struct SkipEquatableMacro: PeerMacro {
    public static func expansion(
        of _: AttributeSyntax,
        providingPeersOf _: some DeclSyntaxProtocol,
        in _: some MacroExpansionContext,
    ) throws -> [DeclSyntax] {
        []
    }
}
