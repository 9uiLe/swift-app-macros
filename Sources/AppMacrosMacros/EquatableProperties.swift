import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

struct EquatableProperty {
    let identifier: TokenSyntax
    let typeAnnotation: TypeSyntax?
}

struct EquatableProperties {
    private(set) var properties: [EquatableProperty] = []
    private(set) var diagnostics: [Diagnostic] = []
    private(set) var hasViewBody = false
    private var hasExcludedInput = false

    init(declaration: StructDeclSyntax, isBodyView: Bool) {
        inspect(declaration.memberBlock.members, isConditional: false, isBodyView: isBodyView)
        if properties.isEmpty, hasExcludedInput, diagnostics.isEmpty {
            diagnose(declaration.structKeyword, .noComparedProperties)
        }
    }

    private mutating func inspect(_ members: MemberBlockItemListSyntax, isConditional: Bool, isBodyView: Bool) {
        for member in members {
            if let conditional = member.decl.as(IfConfigDeclSyntax.self) {
                for clause in conditional.clauses {
                    if let nested = clause.elements?.as(MemberBlockItemListSyntax.self) {
                        inspect(nested, isConditional: true, isBodyView: isBodyView)
                    }
                }
            } else if let variable = member.decl.as(VariableDeclSyntax.self), !isStaticClassOrLazy(variable) {
                inspect(variable, isConditional: isConditional, isBodyView: isBodyView)
            }
        }
    }

    private mutating func inspect(_ variable: VariableDeclSyntax, isConditional: Bool, isBodyView: Bool) {
        let wrappers = variable.attributes.compactMap { $0.as(AttributeSyntax.self) }.map { lastTypeName($0.attributeName) }
        if isBodyView, !Self.parentOwnedWrappers.isDisjoint(with: wrappers) {
            diagnose(variable, .equatableBodyViewForbiddenDynamicProperty)
        }
        for binding in variable.bindings {
            if binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text == "body" {
                hasViewBody = hasViewBody || isViewBodyType(binding.typeAnnotation?.type)
                if isBodyView {
                    diagnoseBody(variable, binding: binding)
                }
            }
        }

        if hasAttribute(named: "SkipEquatable", in: variable.attributes) {
            hasExcludedInput = hasExcludedInput || variable.bindings.contains(where: isStored)
            return
        }
        if !Self.dynamicPropertyWrappers.isDisjoint(with: wrappers) {
            return
        }

        var hasConditionalInput = false
        for binding in variable.bindings where isStored(binding) {
            guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier else {
                diagnose(binding.pattern, .unsupportedPattern)
                continue
            }
            if identifier.text == "body", isViewBodyType(binding.typeAnnotation?.type) {
                continue
            }
            if isTopLevelFunctionType(binding.typeAnnotation?.type) || hasTopLevelClosureLiteralInitializer(binding) {
                hasExcludedInput = true
                continue
            }
            if isConditional {
                hasConditionalInput = true
            } else if containsFunctionType(binding.typeAnnotation?.type) {
                diagnose(binding, .compositeFunctionType)
            } else {
                properties.append(EquatableProperty(identifier: identifier, typeAnnotation: binding.typeAnnotation?.type))
            }
        }
        if hasConditionalInput {
            diagnose(variable, .conditionalStoredProperty)
        }
    }

    private mutating func diagnose(_ node: some SyntaxProtocol, _ message: EquatableDiagnostic) {
        diagnostics.append(Diagnostic(node: Syntax(node), message: message))
    }

    private mutating func diagnoseBody(_ variable: VariableDeclSyntax, binding: PatternBindingSyntax) {
        guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else { return }
        diagnostics.append(Diagnostic(
            node: Syntax(variable),
            message: EquatableDiagnostic.equatableBodyViewDirectBody,
            fixIts: [FixIt(
                message: MacroExpansionFixItMessage("rename `body` to `equatableBody`"),
                changes: [.replace(oldNode: Syntax(pattern), newNode: Syntax(pattern.with(\.identifier, .identifier("equatableBody"))))],
            )],
        ))
    }

    // Comparing wrappers would sample SwiftUI-managed storage rather than a stable parent input.
    private static let dynamicPropertyWrappers: Set<String> = [
        "AccessibilityFocusState", "AppStorage", "Bindable", "Binding", "Environment",
        "EnvironmentObject", "FetchRequest", "FocusedBinding", "FocusedObject",
        "FocusedSceneObject", "FocusedSceneValue", "FocusedValue", "FocusState", "GestureState",
        "Namespace", "NSApplicationDelegateAdaptor", "ObservedObject", "Query", "ScaledMetric",
        "SceneStorage", "SectionedFetchRequest", "State", "StateObject",
        "UIApplicationDelegateAdaptor", "WKApplicationDelegateAdaptor",
    ]

    // Excluding a replaceable source can retain an old subscription after the parent replaces it.
    private static let parentOwnedWrappers: Set<String> = ["Bindable", "ObservedObject", "Binding"]
}
