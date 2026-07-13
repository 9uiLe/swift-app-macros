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

        static func reset() {
            parentBody = 0
            gatedBody = 0
            controlBody = 0
        }
    }

    private final class Driver: ObservableObject {
        @Published var tick = 0
        @Published var childValue = 0
    }

    // `noise` changes on every parent render but is excluded from the generated
    // `==`, so each render is structurally distinct while staying `==`-equal.
    // A changing closure would seem more realistic, but closure identity is
    // allocator-dependent (a freed context can be reallocated at the same
    // address, making the structural diff see "unchanged" nondeterministically),
    // so a plain excluded Int keeps the scenario deterministic.
    @Equatable
    private struct GatedChild: EquatableBodyView {
        let value: Int
        @SkipEquatable let noise: Int

        var equatableBody: some View {
            let _ = RenderLog.gatedBody += 1
            Text(verbatim: "\(value)")
        }
    }

    // Identical shape without Equatable: measures how much parent churn reaches
    // an ungated child in the same window, so the suppression assertion is
    // calibrated against the test environment instead of a fixed count —
    // SwiftUI occasionally re-evaluates even gated bodies (timing-dependent
    // warm-up passes), so absolute counts are not deterministic here.
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
                GatedChild(value: driver.childValue, noise: driver.tick)
                ControlChild(value: driver.childValue, noise: driver.tick)
            }
        }
    }

    // Pins the mounted, user-visible contract: in a real AppKit hierarchy an
    // EquatableBodyView conformer is (a) re-evaluated when a compared input
    // changes and (b) skipped in steady state while parent churn re-renders an
    // ungated twin. Assertions are ratios against the control twin, not exact
    // counts: SwiftUI re-evaluates gated bodies on cold-start passes and has
    // skip paths beside EquatableView's `==` (measured on macOS 26), so
    // absolute counts — and mechanism-isolating negative controls — are
    // environment-dependent. `==` codegen itself is covered deterministically
    // by the expansion and runtime-equality tests.
    @Suite("Render suppression", .serialized)
    @MainActor
    struct RenderSuppressionTests {
        @Test("equal inputs: gated child re-renders far less than an ungated twin")
        func equalInputsSuppressEquatableBody() {
            RenderLog.reset()
            let driver = Driver()
            let window = mount(driver)
            defer { window.close() }

            pump(until: { RenderLog.parentBody >= 1 && RenderLog.gatedBody >= 1 })

            // Warm-up: the first updates after mounting (and after a cold start of
            // the render server connection) re-evaluate gated bodies without
            // consulting `==`. Steady-state suppression is the contract; cold-start
            // passes are excluded from the measured window.
            for _ in 0 ..< 5 {
                let parentBefore = RenderLog.parentBody
                driver.tick += 1
                pump(until: { RenderLog.parentBody > parentBefore })
            }

            let parentBaseline = RenderLog.parentBody
            let gatedBaseline = RenderLog.gatedBody
            let controlBaseline = RenderLog.controlBody

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
        }

        @Test("changed child input re-evaluates equatableBody")
        func changedInputReevaluatesEquatableBody() {
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

        private func mount(_ driver: Driver) -> NSWindow {
            _ = NSApplication.shared
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: 300),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
            )
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: CountingParent(driver: driver))
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
