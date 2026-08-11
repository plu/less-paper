import ApiInterface
import Components
import SwiftUI

struct DocumentBulkEditTagsConfirmationView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: .x4) {
            Text(.tagBulkEditConfirmation(documentCount))

            if !addTags.isEmpty {
                section(
                    tags: addTags,
                    title: .tagBulkEditConfirmationAdd(addTags.count)
                )
            }

            if !removeTags.isEmpty {
                section(
                    tags: removeTags,
                    title: .tagBulkEditConfirmationRemove(removeTags.count)
                )
            }
        }
    }

    let addTags: [Tag]

    let documentCount: Int

    let removeTags: [Tag]

    @ViewBuilder
    private func section(
        tags: [Tag],
        title: LocalizedStringResource
    ) -> some View {
        VStack(alignment: .leading, spacing: .x3) {
            Text(title)

            ScrollView(.horizontal) {
                HStack(spacing: .x3) {
                    ForEach(tags) { tag in
                        Text(tag.description)
                            .capsule(
                                backgroundColor: Color(hex: tag.color),
                                font: .body,
                                foregroundColor: Color(hex: tag.textColor)
                            )
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }
}
