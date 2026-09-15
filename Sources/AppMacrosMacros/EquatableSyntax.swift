import SwiftSyntax

func isStaticClassOrLazy(_ variable: VariableDeclSyntax) -> Bool {
    variable.modifiers.contains { modifier in
        let name = modifier.name.tokenKind
        return name == .keyword(.static)
            || name == .keyword(.class)
            || name == .keyword(.lazy)
    }
}

func isStored(_ binding: PatternBindingSyntax) -> Bool {
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

func hasAttribute(named expectedName: String, in attributes: AttributeListSyntax) -> Bool {
    attributes.contains { element in
        guard let attribute = element.as(AttributeSyntax.self) else {
            return false
        }
        return typeNameMatches(attribute.attributeName, expectedName)
    }
}

func typeNameMatches(_ type: some TypeSyntaxProtocol, _ expectedName: String) -> Bool {
    lastTypeName(type) == expectedName
}

func lastTypeName(_ type: some TypeSyntaxProtocol) -> String {
    if let identifier = type.as(IdentifierTypeSyntax.self) {
        return identifier.name.text
    }

    if let member = type.as(MemberTypeSyntax.self) {
        return member.name.text
    }

    if let attributed = type.as(AttributedTypeSyntax.self) {
        return lastTypeName(attributed.baseType)
    }

    if let someOrAny = type.as(SomeOrAnyTypeSyntax.self) {
        return lastTypeName(someOrAny.constraint)
    }

    return type.trimmedDescription.split(separator: ".").last.map(String.init) ?? type.trimmedDescription
}

func isViewBodyType(_ type: TypeSyntax?) -> Bool {
    guard let type else {
        return false
    }

    if let someOrAny = type.as(SomeOrAnyTypeSyntax.self) {
        return typeNameMatches(someOrAny.constraint, "View")
    }

    return false
}

func isTopLevelFunctionType(_ type: TypeSyntax?) -> Bool {
    guard let type else {
        return false
    }
    if type.is(FunctionTypeSyntax.self) {
        return true
    }
    if let attributed = type.as(AttributedTypeSyntax.self) {
        return isTopLevelFunctionType(attributed.baseType)
    }
    if let optional = type.as(OptionalTypeSyntax.self) {
        return isTopLevelFunctionType(optional.wrappedType)
    }
    if let unwrapped = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
        return isTopLevelFunctionType(unwrapped.wrappedType)
    }
    if let tuple = type.as(TupleTypeSyntax.self), tuple.elements.count == 1,
       let element = tuple.elements.first
    {
        return isTopLevelFunctionType(element.type)
    }
    return false
}

func containsFunctionType(_ type: TypeSyntax?) -> Bool {
    guard let type else {
        return false
    }

    let finder = FunctionTypeFinder(viewMode: .sourceAccurate)
    finder.walk(Syntax(type))
    return finder.foundFunctionType
}

func hasTopLevelClosureLiteralInitializer(_ binding: PatternBindingSyntax) -> Bool {
    guard let expression = binding.initializer?.value else {
        return false
    }

    return expression.is(ClosureExprSyntax.self)
}

private final class FunctionTypeFinder: SyntaxVisitor {
    var foundFunctionType = false

    override func visit(_: FunctionTypeSyntax) -> SyntaxVisitorContinueKind {
        foundFunctionType = true
        return .skipChildren
    }
}

func accessModifier(for structDecl: StructDeclSyntax) -> String {
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

func genericWhereClause(
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

    guard !usedParameterNames.isEmpty else {
        return ""
    }

    let constraints = usedParameterNames.sorted().map { "\($0): Equatable" }.joined(separator: ", ")
    return " where \(constraints)"
}

func genericParameterNames(
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
