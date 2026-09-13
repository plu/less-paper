import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import Get

// One function per wire shape, and no idea which server it is talking to. The version branch lives in
// the use cases, where a test can stub this and assert which call was made.
@DependencyClient
struct FileTaskRepository: Sendable {

    var acknowledgeFileTasks: @Sendable (
        _ ids: [FileTask.Id],
        _ server: Server
    ) async throws -> Void

    var getFailedFileTaskCountV10: @Sendable (
        _ server: Server
    ) async throws -> Int

    var getFailedFileTaskPayloadsV9: @Sendable (
        _ server: Server
    ) async throws -> [FileTaskPayloadV9]

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
        acknowledgeFileTasks: { _, _ in },
        getFailedFileTaskCountV10: { _ in 0 },
        getFailedFileTaskPayloadsV9: { _ in [] },
        getFileTasksV10: { _, _, _ in .init() },
        getFileTasksV9: { _ in [] }
    )

    static let testValue = Self(
        acknowledgeFileTasks: { _, _ in },
        getFailedFileTaskCountV10: { _ in 0 },
        getFailedFileTaskPayloadsV9: { _ in [] },
        getFileTasksV10: { _, _, _ in .init() },
        getFileTasksV9: { _ in [] }
    )
}

extension FileTaskRepository: DependencyKey {

    static let liveValue = Self(
        acknowledgeFileTasks: { ids, server in
            try await acknowledge(ids: ids, path: "/api/tasks/acknowledge/", server: server)
        },
        getFailedFileTaskCountV10: getFailedFileTaskCountV10(server:),
        getFailedFileTaskPayloadsV9: getFailedFileTaskPayloadsV9(server:),
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
        ids: [FileTask.Id],
        path: String,
        server: Server
    ) async throws {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: path,
                method: .post,
                body: AcknowledgeBody(tasks: ids)
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

    // A separate request from getFileTasksV9 below rather than a shared one: the list path needs all
    // four statuses, and this one exists purely to keep the badge cheap. On the dev instance the
    // unfiltered list is ~1000 rows on every inbox appearance; this narrows the response to the rows
    // that could possibly count.
    //
    // The status value is UPPERCASE and deliberately not FileTaskStatus.apiQueryValue, which is
    // lower case and belongs to v10 only. Measured live against 2.15.3 and 2.19.6: `status=FAILURE`
    // returns the true unacknowledged failure count, `status=failure` returns zero. Using
    // apiQueryValue here would make the badge silently read 0 forever.
    //
    // The result is still run through the same in-memory filter as v9's list path: task_type is not
    // provably honoured by every server (every fixture row was consume_file, so that could not be
    // tested), and paperless 2.0.x ignores query parameters entirely. This query is an optimisation,
    // not the source of truth.
    static func getFailedFileTaskPayloadsV9(server: Server) async throws -> [FileTaskPayloadV9] {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/tasks/",
                method: .get,
                query: [
                    ("task_type", "consume_file"),
                    ("status", "FAILURE"),
                    ("acknowledged", "false")
                ]
            ))
            .value
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
