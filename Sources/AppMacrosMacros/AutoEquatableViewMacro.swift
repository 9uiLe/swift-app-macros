import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct AutoEquatableViewMacro: MemberMacro, ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo _: [TypeSyntax],
        in _: some MacroExpansionContext,
    ) throws -> [DeclSyntax] {
        guard let declaration = declaration.as(StructDeclSyntax.self),
              EquatableConformances(declaration).contains("View")
        else { return [] }
        let plan = EquatableExpansionPlan(attribute: node, declaration: declaration)
        guard plan.isValid else { return [] }
        if plan.hasUnsafeParentInput {
            let access = accessModifier(for: declaration)
            let body: DeclSyntax = """
            \(raw: access)var body: some View {
                equatableBody
            }
            """
            return [body]
        }
        return [plan.equalityFunction(for: declaration.name.trimmedDescription)]
    }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo _: [TypeSyntax],
        in context: some MacroExpansionContext,
    ) throws -> [ExtensionDeclSyntax] {
        guard let declaration = declaration.as(StructDeclSyntax.self),
              EquatableConformances(declaration).contains("View")
        else {
            context.diagnose(Diagnostic(node: Syntax(declaration), message: EquatableDiagnostic.autoEquatableViewRequiresView))
            return []
        }
        let plan = EquatableExpansionPlan(attribute: node, declaration: declaration)
        for diagnostic in plan.diagnostics {
            if plan.hasUnsafeParentInput,
               let code = diagnostic.diagMessage as? EquatableDiagnostic,
               code == .noComparedProperties
            {
                continue
            }
            context.diagnose(diagnostic)
        }
        guard plan.isValid, !plan.hasUnsafeParentInput else { return [] }
        let bodyConformance = try ExtensionDeclSyntax("extension \(type.trimmed): @MainActor EquatableBodyView {}")
        return [bodyConformance] + (try plan.extensions(for: type))
    }
}
