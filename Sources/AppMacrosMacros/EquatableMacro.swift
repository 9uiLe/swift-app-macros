import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct EquatableMacro: MemberMacro, ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext,
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            return []
        }

        let expansionContext = expansionContext(for: node, attachedTo: structDecl)
        guard expansionContext.shape == .nonisolatedMember else {
            return []
        }

        let analysis = analyzeProperties(
            in: structDecl,
            excludesDynamicProperties: true,
        )
        analysis.diagnostics.forEach { diagnostic in
            context.diagnose(diagnostic)
        }
        guard analysis.diagnostics.isEmpty else {
            return []
        }

        return [
            makeEqualityFunction(
                for: structDecl.name.text,
                access: accessModifier(for: structDecl),
                isNonisolated: true,
                methodWhereClause: genericWhereClause(for: structDecl, properties: analysis.properties),
                properties: analysis.properties,
            ),
        ]
    }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext,
    ) throws -> [ExtensionDeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            context.diagnose(Diagnostic(
                node: Syntax(declaration),
                message: EquatableDiagnostic.onlyStruct,
            ))
            return []
        }

        // ADR-0015 stale-safety diagnostics. Emitted only here (the extension role
        // always runs for a struct) so they fire exactly once regardless of shape.
        diagnoseEquatableBodyViewViolations(in: structDecl, context: context)

        let expansionContext = expansionContext(for: node, attachedTo: structDecl)
        diagnoseViewLikeStructWithoutDirectConformance(
            in: structDecl,
            expansionContext: expansionContext,
            context: context,
        )
        // Suppress the `: Equatable` anchor ONLY for a directly-written Equatable: the
        // user's declaration anchors the conformance and the member witnesses it. A
        // conformance *inherited* via a refining protocol (EquatableBodyView, Hashable,
        // Comparable) still needs the macro's explicit anchor — the member does not
        // witness an inherited conformance on its own.
        let directlyEquatable = hasDirectConformance(named: "Equatable", in: structDecl)

        switch expansionContext.shape {
        case .extensionConformance:
            let analysis = analyzeProperties(
                in: structDecl,
                excludesDynamicProperties: false,
            )
            analysis.diagnostics.forEach { diagnostic in
                context.diagnose(diagnostic)
            }
            guard analysis.diagnostics.isEmpty else {
                return []
            }

            let genericWhereClause = genericWhereClause(for: structDecl, properties: analysis.properties)
            let function = makeEqualityFunction(
                for: type.trimmedDescription,
                access: accessModifier(for: structDecl),
                isNonisolated: expansionContext.requiresNonisolatedWitness,
                methodWhereClause: "",
                properties: analysis.properties,
            )
            let inheritance = directlyEquatable ? "" : ": Equatable"
            return [
                try ExtensionDeclSyntax(
                    """
                    extension \(type.trimmed)\(raw: inheritance)\(raw: genericWhereClause) {
                        \(function)
                    }
                    """
                ),
            ]

        case .nonisolatedMember:
            guard !directlyEquatable else {
                return []
            }

            let analysis = analyzeProperties(
                in: structDecl,
                excludesDynamicProperties: true,
            )
            let genericWhereClause = genericWhereClause(for: structDecl, properties: analysis.properties)

            return [
                try ExtensionDeclSyntax(
                    """
                    extension \(type.trimmed): Equatable\(raw: genericWhereClause) {
                    }
                    """
                ),
            ]
        }
    }
}

public struct SkipEquatableMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext,
    ) throws -> [DeclSyntax] {
        []
    }
}

private enum ResolvedExpansion {
    case extensionConformance
    case nonisolatedMember
}

private struct EquatableExpansionContext {
    let shape: ResolvedExpansion
    let requiresNonisolatedWitness: Bool
}

private struct EquatableProperty {
    let identifier: TokenSyntax
    let typeAnnotation: TypeSyntax?
    let comparisonAccess: PropertyComparisonAccess
}

private enum PropertyComparisonAccess {
    case direct
    case stateWrappedValue
}

private struct PropertyAnalysis {
    let properties: [EquatableProperty]
    let diagnostics: [Diagnostic]
}

private enum EquatableDiagnostic: DiagnosticMessage {
    case onlyStruct
    case unsupportedPattern
    case equatableBodyViewForbiddenDynamicProperty
    case equatableBodyViewDirectBody
    case viewLikeStructNeedsNonisolated

    var message: String {
        switch self {
        case .onlyStruct:
            "@Equatable can only be attached to a struct"
        case .unsupportedPattern:
            "@Equatable only supports simple stored property names"
        case .equatableBodyViewForbiddenDynamicProperty:
            "@EquatableBodyView cannot compare @StateObject / @ObservedObject / @Binding (not Equatable → stale, ADR-0015); hoist state to a parent and pass value props"
        case .equatableBodyViewDirectBody:
            "@EquatableBodyView must not declare `body` directly (it bypasses the baked-in .equatable() gate, ADR-0015); put the content in `equatableBody`"
        case .viewLikeStructNeedsNonisolated:
            "Struct declares `body: some View` without directly conforming to `View`; add `: View` to the struct declaration or use `@Equatable(.nonisolated)` so `.equatable()` can call `==` without actor hops"
        }
    }

    var diagnosticID: MessageID {
        switch self {
        case .onlyStruct:
            MessageID(domain: "AppMacros.Equatable", id: "onlyStruct")
        case .unsupportedPattern:
            MessageID(domain: "AppMacros.Equatable", id: "unsupportedPattern")
        case .equatableBodyViewForbiddenDynamicProperty:
            MessageID(domain: "AppMacros.Equatable", id: "equatableBodyViewForbiddenDynamicProperty")
        case .equatableBodyViewDirectBody:
            MessageID(domain: "AppMacros.Equatable", id: "equatableBodyViewDirectBody")
        case .viewLikeStructNeedsNonisolated:
            MessageID(domain: "AppMacros.Equatable", id: "viewLikeStructNeedsNonisolated")
        }
    }

    var severity: DiagnosticSeverity {
        switch self {
        case .viewLikeStructNeedsNonisolated:
            .warning
        default:
            .error
        }
    }
}

private func expansionContext(
    for attribute: AttributeSyntax,
    attachedTo structDecl: StructDeclSyntax,
) -> EquatableExpansionContext {
    let needsNonisolatedWitness = needsNonisolatedEquatableWitness(structDecl)
    let shape = explicitExpansionMode(from: attribute)
        ?? (needsNonisolatedWitness ? .nonisolatedMember : .extensionConformance)

    return EquatableExpansionContext(
        shape: shape,
        requiresNonisolatedWitness: needsNonisolatedWitness,
    )
}

private func explicitExpansionMode(from attribute: AttributeSyntax) -> ResolvedExpansion? {
    guard case let .argumentList(arguments)? = attribute.arguments else {
        return nil
    }

    guard let expression = arguments.first?.expression else {
        return nil
    }

    if let memberAccess = expression.as(MemberAccessExprSyntax.self) {
        switch memberAccess.declName.baseName.text {
        case "nonisolated":
            return .nonisolatedMember
        case "extension":
            return .extensionConformance
        default:
            return nil
        }
    }

    return nil
}

private func analyzeProperties(
    in structDecl: StructDeclSyntax,
    excludesDynamicProperties: Bool,
) -> PropertyAnalysis {
    let isView = hasDirectConformance(named: "View", in: structDecl)
    var properties: [EquatableProperty] = []
    var diagnostics: [Diagnostic] = []

    for member in structDecl.memberBlock.members {
        guard let variable = member.decl.as(VariableDeclSyntax.self) else {
            continue
        }

        if isStaticClassOrLazy(variable) || hasAttribute(named: "SkipEquatable", in: variable.attributes) {
            continue
        }

        if excludesDynamicProperties && hasDynamicPropertyWrapper(in: variable.attributes) {
            continue
        }

        for binding in variable.bindings {
            guard let identifierPattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
                diagnostics.append(Diagnostic(
                    node: Syntax(binding.pattern),
                    message: EquatableDiagnostic.unsupportedPattern,
                ))
                continue
            }

            let identifier = identifierPattern.identifier

            if !isStored(binding) {
                continue
            }

            if identifier.text == "body", isView || isViewBodyType(binding.typeAnnotation?.type) {
                continue
            }

            if containsFunctionType(binding.typeAnnotation?.type)
                || hasTopLevelClosureLiteralInitializer(binding)
            {
                continue
            }

            properties.append(EquatableProperty(
                identifier: identifier,
                typeAnnotation: binding.typeAnnotation?.type,
                comparisonAccess: hasPropertyWrapper(named: "State", in: variable.attributes)
                    ? .stateWrappedValue
                    : .direct,
            ))
        }
    }

    return PropertyAnalysis(properties: properties, diagnostics: diagnostics)
}

private func isStaticClassOrLazy(_ variable: VariableDeclSyntax) -> Bool {
    variable.modifiers.contains { modifier in
        let name = modifier.name.tokenKind
        return name == .keyword(.static)
            || name == .keyword(.class)
            || name == .keyword(.lazy)
    }
}

private func isStored(_ binding: PatternBindingSyntax) -> Bool {
    guard let accessorBlock = binding.accessorBlock else {
        return true
    }

    switch accessorBlock.accessors {
    case let .accessors(accessors):
        return accessors.allSatisfy { accessor in
            let specifier = accessor.accessorSpecifier.tokenKind
            return specifier == .keyword(.willSet) || specifier == .keyword(.didSet)
        }
    case .getter:
        return false
    }
}

private func hasAttribute(named expectedName: String, in attributes: AttributeListSyntax) -> Bool {
    attributes.contains { element in
        guard let attribute = element.as(AttributeSyntax.self) else {
            return false
        }
        // @SkipEquatable is a peer marker. Swift only permits it on a single
        // binding, so callers must split multi-binding declarations before
        // marking a property.
        return typeNameMatches(attribute.attributeName, expectedName)
    }
}

private func hasPropertyWrapper(named expectedName: String, in attributes: AttributeListSyntax) -> Bool {
    attributes.contains { element in
        guard let attribute = element.as(AttributeSyntax.self) else {
            return false
        }
        return lastTypeName(attribute.attributeName) == expectedName
    }
}

private func hasDynamicPropertyWrapper(in attributes: AttributeListSyntax) -> Bool {
    // This syntactic allowlist covers Apple SwiftUI DynamicProperty wrappers that are
    // environment/reference-derived and must NOT be read from generated nonisolated
    // equality (they are non-Equatable and/or trap when read outside `body`).
    //
    // `@State` is deliberately NOT in this list: its value is Equatable and is meant to
    // be compared. Excluding it would diverge from the validated EquatableBodyView design
    // (ADR-0015 lists `@State` as supported), where a skipped `@State` can go stale.
    // Custom or future wrappers still need @SkipEquatable.
    let skippedWrapperNames: Set<String> = [
        "AppStorage",
        "Bindable",
        "Binding",
        "AccessibilityFocusState",
        "Environment",
        "EnvironmentObject",
        "FetchRequest",
        "FocusedBinding",
        "FocusedObject",
        "FocusedSceneObject",
        "FocusedSceneValue",
        "FocusedValue",
        "FocusState",
        "GestureState",
        "Namespace",
        "NSApplicationDelegateAdaptor",
        "ObservedObject",
        "Query",
        "ScaledMetric",
        "SceneStorage",
        "SectionedFetchRequest",
        "StateObject",
        "UIApplicationDelegateAdaptor",
        "WKApplicationDelegateAdaptor",
    ]

    return attributes.contains { element in
        guard let attribute = element.as(AttributeSyntax.self) else {
            return false
        }
        return skippedWrapperNames.contains(lastTypeName(attribute.attributeName))
    }
}

private func needsNonisolatedEquatableWitness(_ structDecl: StructDeclSyntax) -> Bool {
    hasDirectConformance(named: "View", in: structDecl)
        || hasDirectConformance(named: "EquatableBodyView", in: structDecl)
        || hasGlobalActorAttribute(in: structDecl.attributes)
}

private let knownGlobalActorAttributeNames: Set<String> = [
    "MainActor",
]

private func hasGlobalActorAttribute(in attributes: AttributeListSyntax) -> Bool {
    attributes.contains { element in
        guard let attribute = element.as(AttributeSyntax.self) else {
            return false
        }

        let name = lastTypeName(attribute.attributeName)
        if knownGlobalActorAttributeNames.contains(name) {
            return true
        }
        // Custom global actors use their type name as the attribute (by convention
        // `*Actor`). Keep this narrower than a bare suffix match on arbitrary attrs.
        return name.count > 5 && name.hasSuffix("Actor")
    }
}

private func hasDirectConformance(named expectedName: String, in structDecl: StructDeclSyntax) -> Bool {
    guard let inheritanceClause = structDecl.inheritanceClause else {
        return false
    }

    return inheritanceClause.inheritedTypes.contains { inheritedType in
        conformanceTypeMatches(inheritedType.type, expectedName)
    }
}

/// Matches a name against an inherited type, expanding a protocol composition
/// (`View & Equatable`) into its elements so each is checked individually.
private func conformanceTypeMatches(_ type: some TypeSyntaxProtocol, _ expectedName: String) -> Bool {
    if let composition = type.as(CompositionTypeSyntax.self) {
        return composition.elements.contains { conformanceTypeMatches($0.type, expectedName) }
    }
    return typeNameMatches(type, expectedName)
}

/// ADR-0015: on an `EquatableBodyView` conformer, forbid non-Equatable dynamic
/// properties (stale bug) and a direct `body` declaration (bypasses the gate).
private func diagnoseEquatableBodyViewViolations(
    in structDecl: StructDeclSyntax,
    context: some MacroExpansionContext,
) {
    guard hasDirectConformance(named: "EquatableBodyView", in: structDecl) else {
        return
    }

    // Recurse into `#if` blocks so a `body` / forbidden wrapper hidden under a
    // conditional is still caught. (A `body` declared in a *separate extension*
    // cannot be seen by an attached macro at all — SE-0389 — and is documented as
    // an inherent limitation.)
    for variable in variableDeclsIncludingConditional(structDecl.memberBlock.members) {
        if hasForbiddenDynamicProperty(in: variable.attributes) {
            context.diagnose(Diagnostic(
                node: Syntax(variable),
                message: EquatableDiagnostic.equatableBodyViewForbiddenDynamicProperty,
            ))
        }

        if declaresBodyProperty(variable) {
            var fixIts: [FixIt] = []
            if let fixIt = renameBodyToEquatableBodyFixIt(in: variable) {
                fixIts.append(fixIt)
            }
            context.diagnose(Diagnostic(
                node: Syntax(variable),
                message: EquatableDiagnostic.equatableBodyViewDirectBody,
                fixIts: fixIts,
            ))
        }
    }
}

/// Warn when a struct looks like a SwiftUI `View` but `: View` is only declared in a
/// separate extension, which forces isolated `==` and breaks `.equatable()`.
private func diagnoseViewLikeStructWithoutDirectConformance(
    in structDecl: StructDeclSyntax,
    expansionContext: EquatableExpansionContext,
    context: some MacroExpansionContext,
) {
    guard expansionContext.shape == .extensionConformance else {
        return
    }
    guard !needsNonisolatedEquatableWitness(structDecl) else {
        return
    }
    guard hasViewBodyMember(in: structDecl) else {
        return
    }

    context.diagnose(Diagnostic(
        node: Syntax(structDecl.structKeyword),
        message: EquatableDiagnostic.viewLikeStructNeedsNonisolated,
    ))
}

private func hasViewBodyMember(in structDecl: StructDeclSyntax) -> Bool {
    structDecl.memberBlock.members.contains { member in
        guard let variable = member.decl.as(VariableDeclSyntax.self) else {
            return false
        }
        guard declaresBodyProperty(variable) else {
            return false
        }
        return variable.bindings.contains { binding in
            guard binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text == "body" else {
                return false
            }
            return isViewBodyType(binding.typeAnnotation?.type)
        }
    }
}

private func renameBodyToEquatableBodyFixIt(in variable: VariableDeclSyntax) -> FixIt? {
    guard let binding = variable.bindings.first(where: { binding in
        binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text == "body"
    }),
        let pattern = binding.pattern.as(IdentifierPatternSyntax.self)
    else {
        return nil
    }

    let newPattern = pattern.with(\.identifier, .identifier("equatableBody"))
    return FixIt(
        message: MacroExpansionFixItMessage("rename `body` to `equatableBody`"),
        changes: [
            .replace(oldNode: Syntax(binding.pattern), newNode: Syntax(newPattern)),
        ],
    )
}

/// All `VariableDeclSyntax` directly in `members` plus those nested inside `#if`
/// blocks. Used by diagnostics (which must see conditional declarations); the
/// equality comparison deliberately does NOT recurse into `#if`.
private func variableDeclsIncludingConditional(
    _ members: MemberBlockItemListSyntax
) -> [VariableDeclSyntax] {
    var result: [VariableDeclSyntax] = []
    for member in members {
        if let variable = member.decl.as(VariableDeclSyntax.self) {
            result.append(variable)
        } else if let ifConfig = member.decl.as(IfConfigDeclSyntax.self) {
            for clause in ifConfig.clauses {
                if let nested = clause.elements?.as(MemberBlockItemListSyntax.self) {
                    result.append(contentsOf: variableDeclsIncludingConditional(nested))
                }
            }
        }
    }
    return result
}

private func hasForbiddenDynamicProperty(in attributes: AttributeListSyntax) -> Bool {
    let forbidden: Set<String> = ["StateObject", "ObservedObject", "Binding"]
    return attributes.contains { element in
        guard let attribute = element.as(AttributeSyntax.self) else {
            return false
        }
        return forbidden.contains(lastTypeName(attribute.attributeName))
    }
}

private func declaresBodyProperty(_ variable: VariableDeclSyntax) -> Bool {
    guard !isStaticClassOrLazy(variable) else {
        return false
    }
    return variable.bindings.contains { binding in
        binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text == "body"
    }
}

private func typeNameMatches(_ type: some TypeSyntaxProtocol, _ expectedName: String) -> Bool {
    lastTypeName(type) == expectedName
}

private func lastTypeName(_ type: some TypeSyntaxProtocol) -> String {
    if let identifier = type.as(IdentifierTypeSyntax.self) {
        return identifier.name.text
    }

    if let member = type.as(MemberTypeSyntax.self) {
        return member.name.text
    }

    if let someOrAny = type.as(SomeOrAnyTypeSyntax.self) {
        return lastTypeName(someOrAny.constraint)
    }

    return type.trimmedDescription.split(separator: ".").last.map(String.init) ?? type.trimmedDescription
}

private func isViewBodyType(_ type: TypeSyntax?) -> Bool {
    guard let type else {
        return false
    }

    if let someOrAny = type.as(SomeOrAnyTypeSyntax.self) {
        return typeNameMatches(someOrAny.constraint, "View")
    }

    return false
}

private func containsFunctionType(_ type: TypeSyntax?) -> Bool {
    guard let type else {
        return false
    }

    let finder = FunctionTypeFinder(viewMode: .sourceAccurate)
    finder.walk(Syntax(type))
    return finder.foundFunctionType
}

private func hasTopLevelClosureLiteralInitializer(_ binding: PatternBindingSyntax) -> Bool {
    guard let expression = binding.initializer?.value else {
        return false
    }

    return expression.is(ClosureExprSyntax.self)
}

private final class FunctionTypeFinder: SyntaxVisitor {
    var foundFunctionType = false

    override func visit(_ node: FunctionTypeSyntax) -> SyntaxVisitorContinueKind {
        foundFunctionType = true
        return .skipChildren
    }
}

private func accessModifier(for structDecl: StructDeclSyntax) -> String {
    for modifier in structDecl.modifiers {
        switch modifier.name.tokenKind {
        case .keyword(.public):
            return "public "
        case .keyword(.package):
            return "package "
        default:
            continue
        }
    }
    return ""
}

private func genericWhereClause(
    for structDecl: StructDeclSyntax,
    properties: [EquatableProperty],
) -> String {
    guard let genericParameterClause = structDecl.genericParameterClause else {
        return ""
    }

    let allParameterNames = Set(genericParameterClause.parameters.map(\.name.text))
    guard !allParameterNames.isEmpty else {
        return ""
    }

    var usedParameterNames = Set<String>()
    for property in properties {
        guard let typeAnnotation = property.typeAnnotation else {
            continue
        }
        usedParameterNames.formUnion(
            genericParameterNames(in: typeAnnotation, parameters: allParameterNames),
        )
    }

    if !properties.isEmpty, usedParameterNames.isEmpty {
        usedParameterNames = allParameterNames
    }

    guard !usedParameterNames.isEmpty else {
        return ""
    }

    let constraints = usedParameterNames.sorted().map { "\($0): Equatable" }.joined(separator: ", ")
    return " where \(constraints)"
}

private func genericParameterNames(
    in type: TypeSyntax,
    parameters: Set<String>,
) -> Set<String> {
    let finder = GenericParameterReferenceFinder(parameters: parameters)
    finder.walk(Syntax(type))
    return finder.found
}

private final class GenericParameterReferenceFinder: SyntaxVisitor {
    let parameters: Set<String>
    var found = Set<String>()

    init(parameters: Set<String>) {
        self.parameters = parameters
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: IdentifierTypeSyntax) -> SyntaxVisitorContinueKind {
        if parameters.contains(node.name.text) {
            found.insert(node.name.text)
        }
        return .visitChildren
    }
}

private func makeEqualityFunction(
    for typeName: String,
    access: String,
    isNonisolated: Bool,
    methodWhereClause: String,
    properties: [EquatableProperty],
) -> DeclSyntax {
    let isolation = isNonisolated ? "nonisolated " : ""
    let comparison = makeComparisonExpression(for: properties)

    return DeclSyntax(
        """
        \(raw: access)\(raw: isolation)static func == (lhs: \(raw: typeName), rhs: \(raw: typeName)) -> Bool\(raw: methodWhereClause) {
            return \(comparison)
        }
        """
    )
}

private func makeComparisonExpression(for properties: [EquatableProperty]) -> ExprSyntax {
    guard let firstProperty = properties.first else {
        return ExprSyntax(BooleanLiteralExprSyntax(literal: .keyword(.true)))
    }

    let firstComparison = makeEqualityExpression(for: firstProperty)

    return properties.dropFirst().reduce(firstComparison) { partialResult, property in
        ExprSyntax(InfixOperatorExprSyntax(
            leftOperand: partialResult,
            operator: ExprSyntax(BinaryOperatorExprSyntax(
                operator: .binaryOperator("&&", leadingTrivia: .space, trailingTrivia: .space),
            )),
            rightOperand: makeEqualityExpression(for: property),
        ))
    }
}

private func makeEqualityExpression(for property: EquatableProperty) -> ExprSyntax {
    switch property.comparisonAccess {
    case .direct:
        let lhs = makeMemberAccess(baseName: "lhs", memberName: property.identifier)
        let rhs = makeMemberAccess(baseName: "rhs", memberName: property.identifier)
        return makeBinaryEquality(lhs: lhs, rhs: rhs)

    case .stateWrappedValue:
        // `@State` wrapped properties are MainActor-isolated on the struct accessor,
        // but the backing `State` storage's `wrappedValue` is readable from
        // `nonisolated ==` (SwiftUI's intended comparison path for `.equatable()`).
        let backingName = "_\(property.identifier.text)"
        let lhs = makeMemberAccess(
            base: makeMemberAccess(baseName: "lhs", memberName: .identifier(backingName)),
            memberName: .identifier("wrappedValue"),
        )
        let rhs = makeMemberAccess(
            base: makeMemberAccess(baseName: "rhs", memberName: .identifier(backingName)),
            memberName: .identifier("wrappedValue"),
        )
        return makeBinaryEquality(lhs: lhs, rhs: rhs)
    }
}

private func makeBinaryEquality(lhs: ExprSyntax, rhs: ExprSyntax) -> ExprSyntax {
    ExprSyntax(InfixOperatorExprSyntax(
        leftOperand: lhs,
        operator: ExprSyntax(BinaryOperatorExprSyntax(
            operator: .binaryOperator("==", leadingTrivia: .space, trailingTrivia: .space),
        )),
        rightOperand: rhs,
    ))
}

private func makeMemberAccess(baseName: String, memberName: TokenSyntax) -> ExprSyntax {
    makeMemberAccess(
        base: ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier(baseName))),
        memberName: memberName,
    )
}

private func makeMemberAccess(base: ExprSyntax, memberName: TokenSyntax) -> ExprSyntax {
    ExprSyntax(MemberAccessExprSyntax(
        base: base,
        period: .periodToken(),
        declName: DeclReferenceExprSyntax(baseName: .identifier(memberName.text)),
    ))
}
