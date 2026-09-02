import ApiInterface
import Components
import Dependencies
import DesignTokens
import Nuke
import NukeUI
import SwiftUI

public struct DocumentImage: View {
    public var body: some View {
        ZStack {
            LazyImage(url: url) { state in
                if let image = state.image {
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: size.width, height: size.height)
                        .clipped()
                } else if state.error != nil {
                    ZStack {
                        Color.m3ErrorContainer
                        Image(systemName: "photo.trianglebadge.exclamationmark")
                            .resizable()
                            .scaledToFit()
                            .frame(width: size.width * 0.5, height: size.height * 0.5)
                            .clipped()
                            .foregroundStyle(Color.m3OnErrorContainer)
                            .padding(.x5)
                    }
                    .frame(width: size.width, height: size.height)
                } else {
                    Color.m3SurfaceDim
                        .frame(width: size.width, height: size.height)
                }
            }
            .processors([.resize(size: size)])
            .pipeline(imagePipeline(server))
        }
    }

    public init(
        document: Document.Id,
        server: Server,
        size: CGSize
    ) {
        self.document = document
        self.server = server
        self.size = size
    }

    private var url: URL {
        server.url.appendingPathComponent("/api/documents/\(document)/thumb/")
    }

    private let document: Document.Id
    private let server: Server
    private let size: CGSize

    @Dependency(\.imagePipeline.build)
    private var imagePipeline
}

extension DocumentImage {

    static func testValue(
        size: CGSize = .init(width: 240, height: 240)
    ) -> Self {
        .init(
            document: 1,
            server: .testValue(),
            size: size
        )
    }
}

#Preview {
    DocumentImage.testValue()

    withDependencies {
        $0.imagePipeline = .failingValue
    } operation: {
        DocumentImage.testValue()
    }

    withDependencies {
        $0.imagePipeline = .loadingValue
    } operation: {
        DocumentImage.testValue()
    }
}
