@testable import Logging

import Dependencies
import Foundation
import Testing

@Suite
struct DeviceContextTests {

    @Test
    func test_launchLine_readsAsOneScannableLine() {
        let context = DeviceContext(
            appName: { "LessPaper" },
            appVersion: { "2.4.1" },
            appBuild: { "312" },
            systemVersion: { "26.0" },
            deviceModel: { "iPhone17,2" },
            locale: { "de_DE" },
            buildConfiguration: { "release" }
        )

        #expect(context.launchLine() == "LessPaper 2.4.1 (312) · iOS 26.0 · iPhone17,2 · de_DE · release")
    }

    // LogWriter splits parsed columns on a double space, so a message containing one would come
    // back from entries() with its tail in the wrong field.
    @Test
    func test_launchLine_containsNoDoubleSpace() {
        let context = DeviceContext(
            appName: { "LessPaper" },
            appVersion: { "2.4.1" },
            appBuild: { "312" },
            systemVersion: { "26.0" },
            deviceModel: { "iPhone17,2" },
            locale: { "de_DE" },
            buildConfiguration: { "release" }
        )

        #expect(!context.launchLine().contains("  "))
    }

    @Test
    func test_liveValue_answersSomethingForEveryField() {
        let context = DeviceContext.liveValue

        #expect(!context.appVersion().isEmpty)
        #expect(!context.systemVersion().isEmpty)
        #expect(!context.deviceModel().isEmpty)
        #expect(!context.locale().isEmpty)
    }
}
