#if canImport(SwiftUI)
    import SwiftUI

    /// A MainActor view whose default `body` applies `.equatable()` to its content.
    ///
    /// Declare conformance as `: @MainActor EquatableBodyView` when using `@Equatable`.
    /// Call sites use the view directly. Equal parent inputs suppress content updates.
    ///
    /// Compared properties must represent the inputs that determine display and actions.
    /// `@Equatable` excludes closures and known SwiftUI dynamic properties. Owned
    /// `@State` / `@StateObject` are supported. Read replaceable `@ObservedObject`,
    /// `@Bindable`, or `@Binding` sources in a parent and pass comparable values.
    /// Excluded values must remain valid while compared inputs are equal.
    ///
    /// Implement `equatableBody` and leave `body` to the default implementation.
    /// `@Equatable` diagnoses a directly declared `body` or a replaceable source.
    @MainActor
    public protocol EquatableBodyView: View, Equatable {
        associatedtype EquatableBody: View

        /// The content whose updates from parent inputs are governed by equality.
        @ViewBuilder var equatableBody: EquatableBody { get }
    }

    public extension EquatableBodyView {
        var body: some View {
            EquatableBodyHost(host: self).equatable()
        }
    }

    private struct EquatableBodyHost<Content: EquatableBodyView>: View, @MainActor Equatable {
        let host: Content

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.host == rhs.host
        }

        var body: Content.EquatableBody {
            host.equatableBody
        }
    }
#endif
