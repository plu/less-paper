import ApiInterface
import Components
import DesignTokens
import IdentifiedCollections
import SwiftUI

struct DocumentFilterCustomFieldField: View {

    let fields: IdentifiedArrayOf<CustomField>

    let query: CustomFieldQuery?

    var body: some View {
        Field(.customFields) {
            HStack(spacing: .x3) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.title2)
                    .foregroundStyle(Color.m3Primary)
                if let summary, !summary.isEmpty {
                    ScrollView(.horizontal) {
                        Text(summary)
                            .capsule()
                    }
                    .scrollIndicators(.hidden)
                } else {
                    Text(.any).capsule()
                    Spacer()
                }
            }
        }
    }

    private var summary: String? {
        query?.summary(fields: fields)
    }
}

#Preview {
    VStack(spacing: .x3) {
        DocumentFilterCustomFieldField(fields: [], query: nil)
        DocumentFilterCustomFieldField(
            fields: IdentifiedArray(uniqueElements: [CustomField].previewValue),
            query: .group(.and, [
                .atom(.init(field: 4, op: .gt, value: .number(100))),
                .atom(.init(field: 3, op: .exists, value: .bool(true)))
            ])
        )
    }
    .padding()
    .background(Color.m3Surface)
}
