@testable import Components

import SwiftUI
import Testing

@Suite
struct PopupPresenterTests {

    @Test
    func present_resolving_returnsTheResolvedValue() async throws {
        let recorder = DismissRecorder()
        let presenter = PopupPresenter(
            dismiss: { await recorder.record() },
            present: { popup in _ = await popup() }
        )

        let result: Bool? = await presenter.present { resolve in
            resolve(true)
            return EmptyView()
        }

        #expect(result == true)
        await #expect(recorder.count == 1)
    }

    @Test
    func present_resolving_ignoresLaterResolutions() async throws {
        let recorder = DismissRecorder()
        let presenter = PopupPresenter(
            dismiss: { await recorder.record() },
            present: { popup in _ = await popup() }
        )

        let result: Bool? = await presenter.present { resolve in
            resolve(true)
            resolve(false)
            return EmptyView()
        }

        #expect(result == true)
        await #expect(recorder.count == 1)
    }

    @Test
    func present_resolving_supportsCustomViewsAndResults() async throws {
        let recorder = DismissRecorder()
        let presenter = PopupPresenter(
            dismiss: { await recorder.record() },
            present: { popup in _ = await popup() }
        )

        let result: ExampleChoice? = await presenter.present { resolve in
            resolve(.selected(id: 2))
            return ExamplePopupView(resolve: resolve)
        }

        #expect(result == .selected(id: 2))
        await #expect(recorder.count == 1)
    }
}

private enum ExampleChoice: Equatable, Sendable {
    case dismissed
    case selected(id: Int)
}

private struct ExamplePopupView: View {
    var body: some View {
        VStack {
            ForEach(1 ... 3, id: \.self) { id in
                Button("Option \(id)") {
                    resolve(.selected(id: id))
                }
            }

            Button("Dismiss") {
                resolve(.dismissed)
            }
        }
    }

    let resolve: @Sendable (ExampleChoice) -> Void
}

private actor DismissRecorder {

    private(set) var count = 0

    func record() {
        count += 1
    }
}
