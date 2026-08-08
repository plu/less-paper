import ComposableArchitecture
import Dependencies
import ShareFeature
import SwiftUI
import UIKit

final class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        prepareDependencies {
            $0.popupPresentationController = self
        }

        let store = Store(
            initialState: ShareExtensionReducer.State(
                input: .extensionContext(extensionContext)
            ),
            reducer: {
                ShareExtensionReducer()
            }
        )

        let childViewController = UIHostingController(
            rootView: ShareExtensionView(
                store: store
            )
        )

        childViewController.willMove(toParent: self)
        addChild(childViewController)
        childViewController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(childViewController.view)

        NSLayoutConstraint.activate([
            childViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            childViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            childViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            childViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        childViewController.didMove(toParent: self)
    }
}
