import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct AppMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        EquatableMacro.self,
        AutoEquatableViewMacro.self,
        SkipEquatableMacro.self,
    ]
}
