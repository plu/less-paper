import ApiInterface
import ComposableArchitecture
import IdentifiedCollections

extension FileTaskListReducer.State {

    static func testValue(
        segment: FileTaskStatus = .complete,
        tasks: IdentifiedArrayOf<FileTask> = [.testValue()],
        isLoaded: Bool = true,
        server: Server = .testValue()
    ) -> Self {
        .init(
            segment: segment,
            tasks: tasks,
            isLoaded: isLoaded,
            server: server
        )
    }
}
