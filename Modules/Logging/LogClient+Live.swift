import Dependencies
import Foundation

extension LogClient: DependencyKey {

    public static let liveValue = Self(
        record: { message, level, category in
            // Detached, because recording must never inherit - or block - the actor a failing
            // feature happens to be running on.
            Task.detached(priority: .utility) {
                await LogWriter.shared.record(message, level: level, category: category)
            }
        },
        entries: { await LogWriter.shared.entries() },
        fileURLs: { await LogWriter.shared.fileURLs() },
        clear: { await LogWriter.shared.clear() }
    )
}
