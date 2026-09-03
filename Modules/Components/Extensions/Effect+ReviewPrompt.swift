import ComposableArchitecture
import Dependencies
import Foundation

public extension Effect {

    // Delayed rather than immediate. Both call sites fire while a sheet is on its way out, and a
    // review prompt asked for into a view hierarchy mid-transition is dropped without a word.
    static func requestReview(
        _ moment: ReviewMoment,
        fileID: StaticString = #fileID,
        filePath: StaticString = #filePath,
        line: UInt = #line,
        column: UInt = #column
    ) -> ComposableArchitecture.Effect<Action> {
        .run(
            operation: { _ in
                @Dependency(\.continuousClock)
                var clock

                @Dependency(\.reviewPrompt.record)
                var record

                try await clock.sleep(for: .seconds(1))
                await record(moment)
            },
            catch: { _, _ in },
            fileID: fileID,
            filePath: filePath,
            line: line,
            column: column
        )
    }
}
