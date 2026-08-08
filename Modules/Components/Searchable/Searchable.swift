import IssueReporting
import SwiftUI

public struct Searchable<Content: View>: View {
    public var body: some View {
        if isTesting {
            content
        } else {
            NavigationStack {
                content
            }
        }
    }

    public init(
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
    }

    private let content: Content
}
