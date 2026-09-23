import Dependencies
import DependenciesMacros
import Foundation
import SwiftMessages
import SwiftUI

@DependencyClient
public struct ToastPresenter: Sendable {
    public var present: @Sendable (
        _ toast: Toast
    ) async -> Void

    // Returns whether the button was tapped, rather than taking a closure, so callers stay value
    // based: a closure payload would have to live on `Toast`, which is `Equatable` and `Hashable`
    // precisely because tests collect the toasts a reducer presents and assert on them.
    public var presentAction: @Sendable (
        _ toast: Toast,
        _ actionTitle: String
    ) async -> Bool = { _, _ in false }
}

extension ToastPresenter: TestDependencyKey {
    public static let previewValue = Self()
    public static let testValue = Self()
}

public extension DependencyValues {
    var toastPresenter: ToastPresenter {
        get { self[ToastPresenter.self] }
        set { self[ToastPresenter.self] = newValue }
    }
}

extension ToastPresenter: DependencyKey {
    public static let liveValue = Self(
        present: present(toast:),
        presentAction: presentAction(toast:actionTitle:)
    )
}

private extension ToastPresenter {

    // Long enough to read the message and decide, which the automatic duration is not: it scales
    // with message length and lands near two seconds for a short one.
    static let actionDuration: TimeInterval = 5

    static func present(
        toast: Toast
    ) async {
        let view = await MessageHostingView(
            id: UUID().uuidString,
            content: ToastView(toast: toast)
        )
        await SwiftMessages.show(
            config: config(for: toast),
            view: view
        )
    }

    static func presentAction(
        toast: Toast,
        actionTitle: String
    ) async -> Bool {
        // Tapping the button hides the message, so `didHide` arrives for both outcomes and is the
        // single place the continuation resumes. `state` carries the tap across that gap and
        // guarantees one resume: SwiftMessages will deliver `didHide` again if the same view is
        // re-presented, and resuming a checked continuation twice traps.
        let state = LockIsolated(ActionState())

        return await withCheckedContinuation { continuation in
            Task { @MainActor in
                let view = MessageHostingView(
                    id: UUID().uuidString,
                    content: ToastView(
                        toast: toast,
                        action: .init(title: actionTitle) {
                            state.withValue { $0.wasTapped = true }
                            SwiftMessages.hide()
                        }
                    )
                )

                var config = config(for: toast)
                config.duration = .seconds(seconds: actionDuration)
                config.eventListeners.append { event in
                    guard case .didHide = event else {
                        return
                    }
                    let resumeWith: Bool? = state.withValue { state in
                        guard !state.hasResumed else {
                            return nil
                        }
                        state.hasResumed = true
                        return state.wasTapped
                    }
                    guard let resumeWith else {
                        return
                    }
                    continuation.resume(returning: resumeWith)
                }

                // Clearing an inbox is a burst of swipes, and SwiftMessages queues by default:
                // without this, five swipes mean twenty-five seconds of toasts, each offering to
                // undo a document the user stopped thinking about four swipes ago. The newest
                // replaces the rest, and every continuation it displaces resumes `false`.
                SwiftMessages.hideAll()
                SwiftMessages.show(
                    config: config,
                    view: view
                )
            }
        }
    }

    static func config(for toast: Toast) -> SwiftMessages.Config {
        var config = SwiftMessages.Config()
        switch toast {
        case .error:
            config.haptic = .error
        case .success:
            config.haptic = .success
        }
        config.presentationContext = .window(windowLevel: .statusBar)
        config.presentationStyle = .top
        return config
    }

    struct ActionState {
        var hasResumed = false
        var wasTapped = false
    }
}
