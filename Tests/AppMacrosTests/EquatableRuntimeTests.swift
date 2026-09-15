import AppMacros
import Testing

@Suite("Equatable runtime")
struct EquatableRuntimeTests {
    @Test
    func `unused generic parameters do not need to be Equatable`() {
        #expect(PhantomBox<NotEquatable>(value: 1) == PhantomBox<NotEquatable>(value: 1))
        #expect(PhantomBox<NotEquatable>(value: 1) != PhantomBox<NotEquatable>(value: 2))
    }

    @Test
    func `explicit nonisolated equality is callable from a detached task`() async {
        let equal = await Task.detached {
            RuntimeNonisolatedBox(value: 2) == RuntimeNonisolatedBox(value: 2)
        }.value
        #expect(equal)
    }

    @Test
    func `custom actor equality is callable on that actor`() async {
        #expect(await compareRenderData())
    }

    @Test
    func `macro generated equality ignores closures at runtime`() {
        let first = RuntimeRow(value: 1, action: {})
        let second = RuntimeRow(value: 1, action: { _ = 1 })

        #expect(first == second)
    }

    @Test
    func `macro generated nonisolated equality ignores closures at runtime`() {
        let first = RuntimeNonisolatedRow(state: 2, action: {})
        let second = RuntimeNonisolatedRow(state: 2, action: { _ = 2 })

        #expect(first == second)
    }

    @Test
    func `macro generated generic equality compiles and compares`() {
        #expect(RuntimeBox(value: 1) == RuntimeBox(value: 1))
    }

    @Test
    func `macro generated generic nonisolated equality compiles and compares`() {
        #expect(RuntimeNonisolatedBox(value: 2) == RuntimeNonisolatedBox(value: 2))
    }

    @Test
    @MainActor
    func `MainActor default Equatable macro compiles`() {
        #expect(RuntimeMainActorModel(value: 1) == RuntimeMainActorModel(value: 1))
    }

    #if canImport(SwiftUI)
        @Test
        @MainActor
        func `MainActor View can compare non-Sendable inputs`() {
            let first = ReferenceView(value: ReferenceInput(1))
            #expect(first == ReferenceView(value: ReferenceInput(1)))
            #expect(first != ReferenceView(value: ReferenceInput(2)))
            _ = first.equatable()
        }

        @Test
        @MainActor
        func `generic View can use a MainActor-isolated Equatable conformance`() {
            let first = GenericView(value: UIInput(value: 1))
            #expect(first == GenericView(value: UIInput(value: 1)))
            #expect(first != GenericView(value: UIInput(value: 2)))
            _ = first.equatable()
        }

        @Test
        @MainActor
        func `Hashable View supports MainActor equality and hashing`() {
            let first = HashableView(value: 1)
            #expect(first == HashableView(value: 1))
            #expect(first.hashValue == HashableView(value: 1).hashValue)
            _ = first.equatable()
        }

        @Test
        @MainActor
        func `SwiftUI View can use default Equatable macro with equatable`() {
            let view = RuntimeCounterView(value: 1, action: {})

            _ = view.equatable()
        }

        @Test
        @MainActor
        func `forced extension SwiftUI View compiles`() {
            let view = RuntimeForcedExtensionCounterView(value: 1)

            _ = view.equatable()
        }
    #endif
}

private struct NotEquatable {}

@Equatable
private struct PhantomBox<Phantom> {
    let value: Int
}

@globalActor
private actor RenderActor {
    static let shared = RenderActor()
}

@RenderActor
@Equatable
private struct RenderData {
    var value: Int
}

@RenderActor
private func compareRenderData() -> Bool {
    RenderData(value: 1) == RenderData(value: 1)
}

@Equatable
private struct RuntimeRow {
    let value: Int
    let action: () -> Void
}

@Equatable(.nonisolated)
private struct RuntimeNonisolatedRow {
    let state: Int
    let action: () -> Void
}

@Equatable
private struct RuntimeBox<T> {
    let value: T
}

@Equatable(.nonisolated)
private struct RuntimeNonisolatedBox<T> {
    let value: T
}

@MainActor
@Equatable
private struct RuntimeMainActorModel {
    let value: Int
}

#if canImport(SwiftUI)
    import SwiftUI

    private final nonisolated class ReferenceInput: Equatable {
        var value: Int

        init(_ value: Int) {
            self.value = value
        }

        static func == (lhs: ReferenceInput, rhs: ReferenceInput) -> Bool {
            lhs.value == rhs.value
        }
    }

    @MainActor
    @Equatable
    private struct ReferenceView: View {
        let value: ReferenceInput
        var body: some View {
            Text(verbatim: "\(value.value)")
        }
    }

    @MainActor
    private struct UIInput: @MainActor Equatable {
        let value: Int

        static func == (lhs: Self, rhs: Self) -> Bool {
            MainActor.assertIsolated()
            return lhs.value == rhs.value
        }
    }

    @Equatable
    private struct GenericView<Value>: View {
        let value: Value
        var body: some View {
            Text(verbatim: "\(value)")
        }
    }

    @Equatable
    private struct HashableView: View, @MainActor Hashable {
        let value: Int
        var body: some View {
            Text(verbatim: "\(value)")
        }
    }

    @Equatable
    private struct RuntimeCounterView: View {
        let value: Int
        let action: () -> Void

        var body: some View {
            Text(verbatim: "\(value)")
        }
    }

    @Equatable(.extension)
    private struct RuntimeForcedExtensionCounterView: View {
        let value: Int

        var body: some View {
            Text(verbatim: "\(value)")
        }
    }
#endif
