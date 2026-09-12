import Foundation

// One page of file tasks, whatever the server's idea of a page is. v10 paginates and answers with a
// next page number; v9 has no pagination at all and always answers nil, because it has already
// handed over everything it has.
public struct FileTaskPage: Equatable, Sendable {

    public let nextPage: Int?

    public let tasks: [FileTask]

    public init(
        nextPage: Int? = nil,
        tasks: [FileTask] = []
    ) {
        self.nextPage = nextPage
        self.tasks = tasks
    }
}

public extension FileTaskPage {

    static func testValue(
        nextPage: Int? = nil,
        tasks: [FileTask] = [.testValue()]
    ) -> Self {
        .init(
            nextPage: nextPage,
            tasks: tasks
        )
    }
}
