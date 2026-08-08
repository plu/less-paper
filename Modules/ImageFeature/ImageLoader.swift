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
                    request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
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
        dataLoader.delegate = certificateDelegate
    }

    private nonisolated(nonsending)
    func getToken(_ server: Server) async throws -> String {
        try await getToken(server)
    }

    private let dataLoader: DataLoader
    private let server: Server

    @Dependency(\.certificateDelegate)
    private var certificateDelegate

    @Dependency(\.authenticationProvider.getToken)
    private var getToken
}
