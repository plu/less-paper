import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import SwiftUI
import UIKit

@DependencyClient
struct ForwardAuthSignInPresenter: Sendable {

    // Returns true if the sign-in landed a cookie, false if the user closed the browser.
    var present: @Sendable (_ redirect: ForwardAuthRedirect) async -> Bool = { _ in false }
}

extension ForwardAuthSignInPresenter: TestDependencyKey {

    static let previewValue = Self(
        present: { _ in true }
    )

    static let testValue = Self()
}

extension ForwardAuthSignInPresenter: DependencyKey {

    static let liveValue = Self(
        present: present(redirect:)
    )
}

private extension ForwardAuthSignInPresenter {

    // Presented from the topmost view controller rather than through a .sheet on AppView. The
    // bounce that starts this flow normally arrives while the server form sheet is up - it is the
    // URL probe that gets redirected - and SwiftUI will not present a second sheet from a host
    // that already has one. It queues it instead, which is why the login browser appeared only
    // after the server form was dismissed. Same reasoning as ConfirmationPopupView over
    // .confirmationDialog: anything that has to appear over whatever is on screen is presented,
    // not declared on a view that may itself be covered.
    static func present(redirect: ForwardAuthRedirect) async -> Bool {
        await withCheckedContinuation { continuation in
            Task { @MainActor in
                guard let presenter = topmostViewController() else {
                    continuation.resume(returning: false)
                    return
                }

                let session = ForwardAuthSignInSession(continuation: continuation)
                let controller = UIHostingController(
                    rootView: ForwardAuthSheetView(
                        redirect: redirect,
                        onFinished: { session.finish(signedIn: true) },
                        onCancel: { session.finish(signedIn: false) }
                    )
                )

                session.controller = controller
                controller.presentationController?.delegate = session

                presenter.present(controller, animated: true)

                // UIKit refuses some presentations with nothing but a console log - a presenter
                // mid-dismissal, a view detached from its window. The presenting relationship is
                // established synchronously when it accepts, so nil here means the sheet will
                // never appear. Report cancellation rather than leaking the continuation: a
                // leaked one wedges the whole flow, because state.redirect never clears and every
                // later bounce is guarded off.
                if controller.presentingViewController == nil {
                    session.finish(signedIn: false)
                }
            }
        }
    }

    @MainActor
    static func topmostViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }

        // Not keyWindow: the confirmation popup that precedes this lives in its own SwiftMessages
        // window above the status bar, and that window is still key while it is being torn down.
        // Presenting from its root put the sheet into a dying window and it never appeared. The
        // app's content window is the one at .normal level.
        let window = scene?.windows.first { $0.windowLevel == .normal }

        var controller = window?.rootViewController

        while let presented = controller?.presentedViewController, !presented.isBeingDismissed {
            controller = presented
        }

        return controller
    }
}

@MainActor
private final class ForwardAuthSignInSession: NSObject, UIAdaptivePresentationControllerDelegate {

    // Weak: the presented controller holds the SwiftUI closures that hold this session.
    weak var controller: UIViewController?

    init(continuation: CheckedContinuation<Bool, Never>) {
        self.continuation = continuation
    }

    func finish(signedIn: Bool) {
        controller?.dismiss(animated: true)
        resume(signedIn: signedIn)
    }

    // Swiping the sheet down is the same decision as tapping close.
    func presentationControllerDidDismiss(_: UIPresentationController) {
        resume(signedIn: false)
    }

    private var continuation: CheckedContinuation<Bool, Never>?

    // decidePolicyFor fires for every response coming back from the server's host, so onFinished
    // can arrive more than once for a single sign-in - and a checked continuation resumed twice
    // traps. First outcome wins.
    private func resume(signedIn: Bool) {
        guard let continuation else {
            return
        }

        self.continuation = nil
        continuation.resume(returning: signedIn)
    }
}

extension DependencyValues {

    var forwardAuthSignIn: ForwardAuthSignInPresenter {
        get { self[ForwardAuthSignInPresenter.self] }
        set { self[ForwardAuthSignInPresenter.self] = newValue }
    }
}
