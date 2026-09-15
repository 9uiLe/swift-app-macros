import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder

struct EquatableExpansionPlan {
    enum Placement { case member, extensionConformance }

    private enum Mode: String {
        case automatic
        case extensionConformance = "extension"
        case mainActor
        case nonisolated

        init?(_ attribute: AttributeSyntax) {
            guard let arguments = attribute.arguments else {
                self = .automatic
                return
            }
            guard let arguments = arguments.as(LabeledExprListSyntax.self), arguments.count <= 1 else { return nil }
            guard let expression = arguments.first?.expression, !expression.is(NilLiteralExprSyntax.self) else {
                self = .automatic
                return
            }
            guard let member = expression.as(MemberAccessExprSyntax.self),
                  let mode = Self(rawValue: member.declName.baseName.text), mode != .automatic
            else { return nil }
            self = mode
        }
    }

    enum Isolation: Equatable {
        case inherited
        case nonisolated
        case globalActor(String)

        var modifier: String {
            switch self {
            case .inherited: ""
            case .nonisolated: "nonisolated "
            case let .globalActor(name): "@\(name) "
            }
        }

        var conformanceModifier: String {
            switch self {
            case .inherited, .nonisolated: ""
            case .globalActor: modifier
            }
        }
    }

    let declaration: StructDeclSyntax
    let placement: Placement
    let isolation: Isolation
    let properties: [EquatableProperty]
    let diagnostics: [Diagnostic]
    let hasEquatableConformance: Bool

    var isValid: Bool {
        !diagnostics.contains { $0.diagMessage.severity == .error }
    }

    init(attribute: AttributeSyntax, declaration: StructDeclSyntax) {
        self.declaration = declaration
        let conformances = EquatableConformances(declaration)
        let requestedMode = Mode(attribute)
        let mode = requestedMode ?? .automatic
        isolation = Self.resolveIsolation(mode: mode, declaration: declaration, conformances: conformances)
        placement = mode == .extensionConformance || (mode == .automatic && isolation == .inherited)
            ? .extensionConformance : .member
        hasEquatableConformance = conformances.contains("Equatable")

        let analysis = EquatableProperties(declaration: declaration, isBodyView: conformances.contains("EquatableBodyView"))
        properties = analysis.properties
        var diagnostics = analysis.diagnostics
        if requestedMode == nil {
            diagnostics.append(Diagnostic(node: Syntax(attribute), message: EquatableDiagnostic.unsupportedExpansion))
        }
        for conformance in conformances.entries where ["Equatable", "EquatableBodyView", "Hashable", "Comparable"].contains(conformance.name) {
            let required: String? = switch isolation {
            case let .globalActor(actor): "@\(actor)"
            case .nonisolated: conformance.isolation == nil || conformance.isolation == "nonisolated" ? nil : "nonisolated"
            case .inherited: nil
            }
            if let required, conformance.isolation != required {
                diagnostics.append(EquatableIsolationDiagnostic(protocolName: conformance.name, isolation: required).diagnostic(for: conformance.type))
            }
        }
        if isolation == .inherited, !conformances.contains("View"), analysis.hasViewBody {
            diagnostics.append(Diagnostic(node: Syntax(declaration.structKeyword), message: EquatableDiagnostic.viewLikeStructNeedsIsolation))
        }
        if let equality = declaration.memberBlock.members.compactMap({ $0.decl.as(FunctionDeclSyntax.self) }).first(where: {
            $0.name.text == "==" && $0.signature.parameterClause.parameters.count == 2
                && $0.signature.parameterClause.parameters.allSatisfy {
                    ["Self", declaration.name.text].contains(lastTypeName($0.type))
                }
        }) {
            diagnostics.append(Diagnostic(node: Syntax(equality), message: EquatableDiagnostic.existingEquality))
        }
        self.diagnostics = diagnostics
    }

    func equalityFunction(for typeName: String) -> DeclSyntax {
        let comparisons = properties.map { "lhs.\($0.identifier.trimmedDescription) == rhs.\($0.identifier.trimmedDescription)" }
        let comparison = comparisons.isEmpty ? "true" : comparisons.joined(separator: " && ")
        let whereClause = placement == .member ? genericWhereClause(for: declaration, properties: properties) : ""
        let access = accessModifier(for: declaration)
        let modifiers = if case .globalActor = isolation { isolation.modifier + access } else { access + isolation.modifier }
        return """
        \(raw: modifiers)static func == (lhs: \(raw: typeName), rhs: \(raw: typeName)) -> Bool\(raw: whereClause) {
            return \(raw: comparison)
        }
        """
    }

    func extensions(for type: some TypeSyntaxProtocol) throws -> [ExtensionDeclSyntax] {
        if placement == .member, hasEquatableConformance {
            return []
        }
        // Refining protocols need an explicit Equatable conformance for macro-generated witnesses.
        let inheritance = hasEquatableConformance ? "" : ": \(isolation.conformanceModifier)Equatable"
        let whereClause = genericWhereClause(for: declaration, properties: properties)
        var result = try ExtensionDeclSyntax("extension \(type.trimmed)\(raw: inheritance)\(raw: whereClause) {}")
        if placement == .extensionConformance {
            result.memberBlock.members = [MemberBlockItemSyntax(decl: equalityFunction(for: type.trimmedDescription))]
        }
        return [result]
    }

    private static func resolveIsolation(
        mode: Mode, declaration: StructDeclSyntax, conformances: EquatableConformances,
    ) -> Isolation {
        if mode == .nonisolated { return .nonisolated }
        if mode == .mainActor { return .globalActor("MainActor") }
        if let explicit = conformances.entries.first(where: {
            ["Equatable", "EquatableBodyView"].contains($0.name) && $0.isolation != nil
        })?.isolation {
            return explicit == "nonisolated" ? .nonisolated : .globalActor(String(explicit.dropFirst()))
        }
        if declaration.modifiers.contains(where: { $0.name.tokenKind == .keyword(.nonisolated) }) {
            return .nonisolated
        }
        for case let .attribute(attribute) in declaration.attributes {
            let name = lastTypeName(attribute.attributeName)
            // SwiftSyntax cannot resolve global actors; custom type attributes require the *Actor naming convention.
            if name == "MainActor" || (name.count > 5 && name.hasSuffix("Actor")) {
                return .globalActor(attribute.attributeName.trimmedDescription)
            }
        }
        if conformances.contains("View") || conformances.contains("EquatableBodyView") {
            return .globalActor("MainActor")
        }
        return .inherited
    }
}

struct EquatableConformances {
    struct Entry {
        let name: String
        let isolation: String?
        let type: TypeSyntax
    }

    let entries: [Entry]

    init(_ declaration: StructDeclSyntax) {
        entries = declaration.inheritanceClause?.inheritedTypes.flatMap { Self.entries(in: $0.type) } ?? []
    }

    func contains(_ name: String) -> Bool {
        entries.contains { $0.name == name }
    }

    private static func entries(in type: TypeSyntax, isolation: String? = nil, annotationTarget: TypeSyntax? = nil) -> [Entry] {
        if let attributed = type.as(AttributedTypeSyntax.self) {
            let actor = attributed.attributes.compactMap { $0.as(AttributeSyntax.self) }
                .first(where: { lastTypeName($0.attributeName) != "preconcurrency" })?.attributeName.trimmedDescription
            let isNonisolated = attributed.specifiers.contains { $0.trimmedDescription == "nonisolated" }
            return entries(in: attributed.baseType, isolation: actor.map { "@\($0)" } ?? (isNonisolated ? "nonisolated" : isolation), annotationTarget: type)
        }
        if let composition = type.as(CompositionTypeSyntax.self) {
            return composition.elements.flatMap { entries(in: $0.type, isolation: isolation, annotationTarget: annotationTarget) }
        }
        return [Entry(name: lastTypeName(type), isolation: isolation, type: annotationTarget ?? type)]
    }
}
