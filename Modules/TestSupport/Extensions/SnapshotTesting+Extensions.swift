import Foundation
import SnapshotTesting
import SwiftUI
import Testing
import UIKit

public extension SnapshotTestingConfiguration.Record {
    static let environment: Self = {
        guard let rawValue = ProcessInfo.processInfo.environment["SNAPSHOT_RECORD"] else {
            return .missing
        }
        return Self(rawValue: rawValue) ?? .missing
    }()
}

public func assertSnapshot<Value, Format>(
    of value: @autoclosure () throws -> Value,
    as snapshotting: Snapshotting<Value, Format>,
    named name: String? = nil,
    record recording: Bool? = nil,
    timeout: TimeInterval = 5,
    fileID: StaticString = #fileID,
    file filePath: StaticString = #file,
    // Distinct from `filePath` above, which is `#file` and so carries the module/file form that
    // names the reference. This is the absolute path, and only the caller's is trustworthy.
    sourcePath: StaticString = #filePath,
    testName: String = #function,
    line: UInt = #line,
    column: UInt = #column
) {
    let message = try SnapshotTesting.verifySnapshot(
        of: value(),
        as: snapshotting,
        named: name,
        record: recording,
        snapshotDirectory: snapshotDirectory(fileID: filePath, sourcePath: sourcePath),
        timeout: timeout,
        fileID: fileID,
        file: filePath,
        testName: testName,
        line: line,
        column: column
    )
    guard let message else {
        return
    }

    Issue.record(
        Comment(rawValue: message),
        sourceLocation: SourceLocation(
            fileID: fileID.description,
            filePath: filePath.description,
            line: Int(line),
            column: Int(column)
        )
    )
}

public extension Snapshotting where Value: SwiftUI.View, Format == UIImage {
    static func image(
        precision: Float = 1,
        perceptualPrecision: Float = 1,
        layout: SwiftUISnapshotLayout = .device(config: .iPhone13),
        traits: UITraitCollection = .init()
    ) -> Snapshotting {
        .image(
            drawHierarchyInKeyWindow: false,
            precision: precision,
            perceptualPrecision: perceptualPrecision,
            layout: layout,
            traits: traits
        )
    }
}

// Walks up from the calling test's own source path, never from this file's.
//
// `#filePath` is resolved when the module containing it is compiled, so using this file's would
// bake in wherever TestSupport was built. Under Tuist's binary cache that is another machine
// entirely: the walk then runs to `/` and trips the precondition below, crashing the test process
// rather than failing an assertion — which reads as an unexplained xctest crash and sent a real
// investigation looking at simulators and runtimes first. The caller is a test target, which is
// compiled rather than restored, so its path is the one that can be trusted.
private func snapshotDirectory(fileID: StaticString, sourcePath: StaticString) -> String {
    let fileManager = FileManager.default
    var result = URL(fileURLWithPath: String(sourcePath))
    repeat {
        result.deleteLastPathComponent()
        if fileManager.fileExists(atPath: result.appendingPathComponent("Snapshots").path()) {
            return result
                .appendingPathComponent("Snapshots")
                .appendingPathComponent(String(fileID))
                .deletingPathExtension()
                .path()
        }
        precondition(
            result.path() != "/",
            "Couldn't find a Snapshots directory above \(String(sourcePath)). If that path is not on this machine, the calling module was restored from the binary cache rather than compiled."
        )
    } while true
}

private extension String {
    init(_ staticString: StaticString) {
        self = staticString.withUTF8Buffer {
            String(decoding: $0, as: UTF8.self)
        }
    }
}
