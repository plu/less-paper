import Components
import DesignTokens
import MarkdownUI
import SwiftUI

public struct LicenseView: View {
    public var body: some View {
        ScrollView {
            Markdown(license.content)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .topLeading
                )
                .padding()
        }
        .background(Color.m3SurfaceContainerLowest)
        .navigationTitle(license.name)
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
    }

    public init(license: License) {
        self.license = license
    }

    private let license: License
}

#Preview {
    NavigationStack {
        LicenseView(license: .testValue())
    }
}
