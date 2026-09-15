import SwiftSyntaxMacros

#if canImport(AppMacrosMacros)
    import AppMacrosMacros

    let testMacros: [String: Macro.Type] = [
        "Equatable": EquatableMacro.self,
        "SkipEquatable": SkipEquatableMacro.self,
    ]
#endif
