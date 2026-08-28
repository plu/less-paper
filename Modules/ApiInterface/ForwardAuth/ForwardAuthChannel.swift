import AsyncAlgorithms
import Dependencies

public extension DependencyValues {

    var forwardAuthChannel: AsyncChannel<ForwardAuthEvent> {
        get { self[ForwardAuthChannelKey.self] }
        set { self[ForwardAuthChannelKey.self] = newValue }
    }

    private enum ForwardAuthChannelKey: DependencyKey {
        static let liveValue = AsyncChannel<ForwardAuthEvent>()
        static let testValue = AsyncChannel<ForwardAuthEvent>()
    }
}
