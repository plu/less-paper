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
    testName: String = #function,
    line: UInt = #line,
    column: UInt = #column
) {
    let message = try SnapshotTesting.verifySnapshot(
        of: value(),
        as: snapshotting,
        named: name,
        record: recording,
        snapshotDirectory: snapshotDirectory(file: filePath),
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

private func snapshotDirectory(file: StaticString) -> String {
    let fileManager = FileManager.default
    var result = URL(fileURLWithPath: String(#filePath))
    repeat {
        result.deleteLastPathComponent()
        if fileManager.fileExists(atPath: result.appendingPathComponent("Snapshots").path()) {
            return result
                .appendingPathComponent("Snapshots")
                .appendingPathComponent(String(file))
                .deletingPathExtension()
                .path()
        }
        precondition(result.path() != "/", "Couldn't find a Snapshot directory")
    } while true
}

private extension String {
    init(_ staticString: StaticString) {
        self = staticString.withUTF8Buffer {
            String(decoding: $0, as: UTF8.self)
        }
    }
}
