import Foundation

public extension ShareExtensionReducer.State {

    static func testValue(
        input: ShareExtensionInput = .files([])
    ) -> Self {
        .init(
            input: input
        )
    }
}

public final class TestExtensionContext: NSExtensionContext {

    public static func testValue(
        dismiss: @escaping () -> Void = {},
        fileNames: [String] = [
            "Puky.pdf",
            "Puky-Locked.pdf",
            "TonieBox.pdf"
        ]
    ) -> TestExtensionContext {
        TestExtensionContext(
            dismiss: dismiss,
            fileNames: fileNames
        )
    }

    override public var inputItems: [Any] {
        [
            NSExtensionItem.testValue(fileNames: fileNames)
        ]
    }

    override public func completeRequest(returningItems items: [Any]?, completionHandler: (@Sendable (Bool) -> Void)? = nil) {
        dismiss()
        completionHandler?(true)
    }

    private init(
        dismiss: @escaping () -> Void,
        fileNames: [String]
    ) {
        self.dismiss = dismiss
        self.fileNames = fileNames
        super.init()
    }

    private let dismiss: () -> Void

    private let fileNames: [String]
}

private extension NSExtensionItem {

    static func testValue(
        fileNames: [String]
    ) -> NSExtensionItem {
        let testValue = NSExtensionItem()
        testValue.attachments = fileNames.map(TestItemProvider.init(fileName:))
        return testValue
    }
}

private final class TestItemProvider: NSItemProvider, @unchecked Sendable {

    let fileName: String

    init(fileName: String) {
        self.fileName = fileName
        super.init()
    }

    override func hasItemConformingToTypeIdentifier(_ typeIdentifier: String) -> Bool {
        true
    }

    override func getURL(identifier: String = "com.adobe.pdf") async throws -> URL? {
        URL.projectRoot
            .appendingPathComponent("docker")
            .appendingPathComponent("data")
            .appendingPathComponent(fileName)
    }
}

extension TestExtensionContext {
    static func == (lhs: TestExtensionContext, rhs: TestExtensionContext) -> Bool {
        lhs.fileNames == rhs.fileNames
    }
}
