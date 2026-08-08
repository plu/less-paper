import ComposableArchitecture
import Dependencies
import Foundation

public extension Effect {
    static func toast(
        _ error: Error,
        fileID: StaticString = #fileID,
        filePath: StaticString = #filePath,
        line: UInt = #line,
        column: UInt = #column
    ) -> ComposableArchitecture.Effect<Action> {
        .toast(
            Toast.error(error.localizedDescription),
            fileID: fileID,
            filePath: filePath,
            line: line,
            column: column
        )
    }

    static func toast(
        _ toast: Toast,
        fileID: StaticString = #fileID,
        filePath: StaticString = #filePath,
        line: UInt = #line,
        column: UInt = #column
    ) -> ComposableArchitecture.Effect<Action> {
        .run(
            operation: { _ in
                @Dependency(\.toastPresenter)
                var toastPresenter

                await toastPresenter.present(toast: toast)
            },
            fileID: fileID,
            filePath: filePath,
            line: line,
            column: column
        )
    }
}
