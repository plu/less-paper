import ApiInterface
import Dependencies
import Foundation
import Nuke

struct ImageLoader: Nuke.DataLoading {

    func loadData(
        with request: URLRequest,
        didReceiveData: @escaping @Sendable (Data, URLResponse) -> Void,
        completion: @escaping @Sendable (Error?) -> Void
    ) -> Cancellable {
        let task = Task {
            var cancellable: Cancellable?
            try await withTaskCancellationHandler {
                let token = try await getToken(server)
                var request = request
                if server.url.host() == request.url?.host() {
                    for header in server.headers {
                        request.setValue(header.value, forHTTPHeaderField: header.name)
                    }
                    if let token {
                        // Remote-user mode stores no token: the forward-auth cookie authenticates
                        // the request, and a bare `Token ` header would be rejected. Same rule
                        // ApiClientDelegate applies to every other API call.
                        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
                    }
                }
                cancellable = dataLoader.loadData(with: request, didReceiveData: didReceiveData, completion: completion)
            } onCancel: { [cancellable] in
                cancellable?.cancel()
            }
        }
        return AnyCancellable { [task] in
            task.cancel()
        }
    }

    init(
        dataLoader: DataLoader = .init(),
        server: Server
    ) {
        self.dataLoader = dataLoader
        self.server = server
        dataLoader.delegate = apiSessionDelegate
    }

    private let dataLoader: DataLoader
    private let server: Server

    @Dependency(\.apiSessionDelegate)
    private var apiSessionDelegate

    @Dependency(\.authenticationProvider.getToken)
    private var getToken
}
