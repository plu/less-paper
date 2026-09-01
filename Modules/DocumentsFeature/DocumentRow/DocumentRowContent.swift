import ApiInterface
import Components
import DesignTokens
import SwiftUI

public struct DocumentRowContent: View {

    public var body: some View {
        VStack(alignment: .leading, spacing: .x3) {
            AdaptiveStack(
                horizontalSpacing: .x2,
                verticalAlignment: .top
            ) {
                Text(correspondent)
                    .font(.footnote)
                    .fontWeight(.bold)
                    .foregroundColor(.m3Primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if sizeCategory < .accessibilityMedium {
                    Spacer(minLength: 0)
                }
                Text(DateFormatter.createdDate.string(from: document.created))
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundColor(.m3Outline)
                    .lineLimit(1)
                    .padding(.trailing, .x2)
            }
            Text(document.title)
                .fixedSize(horizontal: false, vertical: true)
                .font(.body)
                .foregroundColor(.m3OnSurface)
                .lineLimit(titleLineLimit)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            Grid(alignment: .leading, horizontalSpacing: .x2) {
                if let asn = document.archiveSerialNumber {
                    GridRow {
                        Image(systemName: "barcode").accessibilityHidden(true)
                        Text(String(asn)).lineLimit(1)
                    }
                }
                if let documentTypeName = documentType {
                    GridRow {
                        Image(systemName: "doc").accessibilityHidden(true)
                        Text(documentTypeName).lineLimit(1)
                    }
                }
                if let storagePathName = storagePath {
                    GridRow {
                        Image(systemName: "folder").accessibilityHidden(true)
                        Text(storagePathName).lineLimit(1)
                    }
                }
            }
        }
        .foregroundColor(.m3Outline)
        .fontWeight(.medium)
        .font(.footnote)
        .padding(sizeCategory >= breakpoint ? .x4 : .x3)
    }

    public init(document: Document, server: Server, titleLineLimit: Int) {
        self.document = document
        self.server = server
        self.titleLineLimit = titleLineLimit
    }

    private let document: Document
    private let server: Server
    private let titleLineLimit: Int

    private var correspondent: String {
        document.correspondent?.get(server)?.name ?? "-"
    }

    private var documentType: String? {
        document.documentType?.get(server)?.name
    }

    private var storagePath: String? {
        document.storagePath?.get(server)?.name
    }

    private let breakpoint = ContentSizeCategory.extraLarge

    @Environment(\.sizeCategory)
    private var sizeCategory
}

public struct DocumentRowTags: View {

    public var body: some View {
        VStack(alignment: .trailing, spacing: .x2) {
            ForEach(tags) { tag in
                Text(tag.name)
                    .capsule(
                        backgroundColor: Color(hex: tag.color),
                        font: .footnote,
                        foregroundColor: Color(hex: tag.textColor)
                    )
            }
        }
        .frame(height: height - .x4, alignment: .top)
        .clipped()
        .padding(.x3)
    }

    public init(tags: [Tag], height: CGFloat) {
        self.tags = tags
        self.height = height
    }

    private let tags: [Tag]
    private let height: CGFloat
}
