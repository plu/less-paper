import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import Get

// One function per wire shape, and no idea which server it is talking to. The version branch lives in
// the use cases, where a test can stub this and assert which call was made.
@DependencyClient
struct FileTaskRepository: Sendable {

    var acknowledgeFileTask: @Sendable (
        _ id: FileTask.Id,
        _ server: Server
    ) async throws -> Void

    var getFailedFileTaskCountV10: @Sendable (
        _ server: Server
    ) async throws -> Int

    var getFileTasksV10: @Sendable (
        _ status: FileTaskStatus,
        _ page: Int,
        _ server: Server
    ) async throws -> FileTaskListOutputV10

    var getFileTasksV9: @Sendable (
        _ server: Server
    ) async throws -> [FileTaskPayloadV9]
}

extension FileTaskRepository: TestDependencyKey {

    static let previewValue = Self(
        acknowledgeFileTask: { _, _ in },
        getFailedFileTaskCountV10: { _ in 0 },
        getFileTasksV10: { _, _, _ in .init() },
        getFileTasksV9: { _ in [] }
    )

    static let testValue = Self(
        acknowledgeFileTask: { _, _ in },
        getFailedFileTaskCountV10: { _ in 0 },
        getFileTasksV10: { _, _, _ in .init() },
        getFileTasksV9: { _ in [] }
    )
}

extension FileTaskRepository: DependencyKey {

    static let liveValue = Self(
        acknowledgeFileTask: { id, server in
            try await acknowledge(id: id, path: "/api/tasks/acknowledge/", server: server)
        },
        getFailedFileTaskCountV10: getFailedFileTaskCountV10(server:),
        getFileTasksV10: getFileTasksV10(status:page:server:),
        getFileTasksV9: getFileTasksV9(server:)
    )
}

extension DependencyValues {

    var fileTaskRepository: FileTaskRepository {
        get { self[FileTaskRepository.self] }
        set { self[FileTaskRepository.self] = newValue }
    }
}

private extension FileTaskRepository {

    static let pageSize = 50

    struct AcknowledgeBody: Encodable {
        let tasks: [FileTask.Id]
    }

    // Only the ids are read; the page exists to carry `count`.
    struct CountOutput: Decodable {
        let count: Int
    }

    static func acknowledge(
        id: FileTask.Id,
        path: String,
        server: Server
    ) async throws {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: path,
                method: .post,
                body: AcknowledgeBody(tasks: [id])
            ))
            .value
    }

    static func getFailedFileTaskCountV10(server: Server) async throws -> Int {
        try await APIClient
            .client(server: server)
            .send(Request<CountOutput>(
                path: "/api/tasks/",
                method: .get,
                query: [
                    ("task_type", "consume_file"),
                    ("status", "failure"),
                    ("acknowledged", "false"),
                    ("page_size", "1")
                ]
            ))
            .value
            .count
    }

    static func getFileTasksV10(
        status: FileTaskStatus,
        page: Int,
        server: Server
    ) async throws -> FileTaskListOutputV10 {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/tasks/",
                method: .get,
                query: [
                    ("task_type", "consume_file"),
                    ("status", status.apiQueryValue),
                    // Every segment hides dismissed rows, not just Failed. The server does not do
                    // this by itself - 3.0.5 answers 173 consume tasks and 168 unacknowledged ones
                    // for the same filter - so without this a row the user swiped away comes back on
                    // the next refresh, and the badge and the list would mean different things.
                    ("acknowledged", "false"),
                    ("ordering", "-date_created"),
                    ("page", String(page)),
                    ("page_size", String(pageSize))
                ]
            ))
            .value
    }

    // No query at all: an old server has no filters to honour, and sending some would only make the
    // request look like it was filtered.
    static func getFileTasksV9(server: Server) async throws -> [FileTaskPayloadV9] {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/tasks/",
                method: .get
            ))
            .value
    }
}
