import Nuke

final class AnyCancellable: Nuke.Cancellable, Sendable {
    let closure: @Sendable () -> Void

    init(_ closure: @Sendable @escaping () -> Void) {
        self.closure = closure
    }

    func cancel() {
        closure()
    }
}
