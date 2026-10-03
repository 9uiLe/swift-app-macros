#if canImport(SwiftUI) && canImport(AppKit)
    import AppKit
    import AppMacros
    import SwiftUI
    import Testing

    @MainActor
    private enum RenderLog {
        static var parentBody = 0
        static var gatedBody = 0
        static var controlBody = 0
        static var comparisons = 0
        static var environmentBody = 0

        static func reset() {
            parentBody = 0
            gatedBody = 0
            controlBody = 0
            comparisons = 0
            environmentBody = 0
        }
    }

    private final class Driver: ObservableObject {
        @Published var tick = 0
        @Published var childValue = 0
    }

    @MainActor
    private struct RenderValue: @MainActor Equatable {
        let text: String

        static func == (lhs: Self, rhs: Self) -> Bool {
            MainActor.assertIsolated()
            RenderLog.comparisons += 1
            return lhs.text == rhs.text
        }
    }

    // Closure identity can be reused by the allocator; an excluded integer makes
    // structurally distinct parent updates deterministic.
    @Equatable
    private struct GatedChild: @MainActor EquatableBodyView {
        let value: RenderValue
        @SkipEquatable let noise: Int

        var equatableBody: some View {
            let _ = RenderLog.gatedBody += 1
            Text(verbatim: value.text)
        }
    }

    // SwiftUI can re-evaluate gated bodies during warm-up, so absolute body counts
    // are less reliable than comparison against an ungated view in the same window.
    private struct ControlChild: View {
        let value: Int
        let noise: Int

        var body: some View {
            let _ = RenderLog.controlBody += 1
            Text(verbatim: "\(value)")
        }
    }

    private struct CountingParent: View {
        @ObservedObject var driver: Driver

        var body: some View {
            let _ = RenderLog.parentBody += 1
            VStack {
                Text(verbatim: "tick \(driver.tick)")
                GatedChild(value: RenderValue(text: "\(driver.childValue)"), noise: driver.tick)
                ControlChild(value: driver.childValue, noise: driver.tick)
            }
        }
    }

    private final class EnvironmentDriver: ObservableObject {
        @Published var dark = false
    }

    @AutoEquatableView
    private struct EnvironmentChild: View {
        let title: String
        @Environment(\.colorScheme) private var scheme

        var equatableBody: some View {
            let _ = RenderLog.environmentBody += 1
            return Text(verbatim: "\(title)-\(scheme == .dark ? "dark" : "light")")
        }
    }

    private struct EnvironmentParent: View {
        @ObservedObject var driver: EnvironmentDriver

        var body: some View {
            EnvironmentChild(title: "Status")
                .environment(\.colorScheme, driver.dark ? .dark : .light)
        }
    }

    @Suite("Render suppression", .serialized)
    @MainActor
    struct RenderSuppressionTests {
        @Test
        func `equal inputs: gated child re-renders far less than an ungated twin`() {
            RenderLog.reset()
            let driver = Driver()
            let window = mount(driver)
            defer { window.close() }

            pump(until: { RenderLog.parentBody >= 1 && RenderLog.gatedBody >= 1 })

            // Cold-start graph passes can bypass equality; measure steady-state updates.
            for _ in 0 ..< 5 {
                let parentBefore = RenderLog.parentBody
                driver.tick += 1
                pump(until: { RenderLog.parentBody > parentBefore })
            }

            let parentBaseline = RenderLog.parentBody
            let gatedBaseline = RenderLog.gatedBody
            let controlBaseline = RenderLog.controlBody
            let comparisonBaseline = RenderLog.comparisons

            for _ in 0 ..< 30 {
                let parentBefore = RenderLog.parentBody
                driver.tick += 1
                pump(until: { RenderLog.parentBody > parentBefore })
            }

            let parentRuns = RenderLog.parentBody - parentBaseline
            let gatedRuns = RenderLog.gatedBody - gatedBaseline
            let controlRuns = RenderLog.controlBody - controlBaseline

            #expect(parentRuns >= 30)
            #expect(controlRuns >= 30)
            #expect(gatedRuns <= controlRuns / 2)
            #expect(RenderLog.comparisons > comparisonBaseline)
        }

        @Test
        func `changed child input re-evaluates equatableBody`() {
            RenderLog.reset()
            let driver = Driver()
            let window = mount(driver)
            defer { window.close() }

            pump(until: { RenderLog.gatedBody >= 1 })
            let gatedBaseline = RenderLog.gatedBody

            driver.childValue += 1
            pump(until: { RenderLog.gatedBody >= gatedBaseline + 1 })

            #expect(RenderLog.gatedBody >= gatedBaseline + 1)
        }

        @Test
        func `environment changes invalidate a gated child with equal parent inputs`() {
            RenderLog.reset()
            let driver = EnvironmentDriver()
            let window = mount(EnvironmentParent(driver: driver))
            defer { window.close() }

            pump(until: { RenderLog.environmentBody >= 1 })
            let baseline = RenderLog.environmentBody
            driver.dark = true
            pump(until: { RenderLog.environmentBody > baseline })

            #expect(RenderLog.environmentBody > baseline)
        }

        private func mount(_ driver: Driver) -> NSWindow {
            mount(CountingParent(driver: driver))
        }

        private func mount(_ view: some View) -> NSWindow {
            _ = NSApplication.shared
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: 300),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
            )
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: view)
            window.orderFrontRegardless()
            return window
        }

        private func pump(until condition: () -> Bool, timeout: TimeInterval = 2) {
            let deadline = Date().addingTimeInterval(timeout)
            repeat {
                RunLoop.main.run(until: Date().addingTimeInterval(0.01))
            } while !condition() && Date() < deadline
        }
    }
#endif
