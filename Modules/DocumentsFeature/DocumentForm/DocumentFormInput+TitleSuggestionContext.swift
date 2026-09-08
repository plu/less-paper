import ApiInterface
import Foundation
import Intelligence

extension DocumentFormInput {

    // Content is passed in rather than read from the input, because the form holds it separately —
    // nil until the full document lands, since the list payload truncates it.
    func titleSuggestionContext(content: String?, server: Server) -> TitleSuggestionContext {
        TitleSuggestionContext(
            archiveSerialNumber: archiveSerialNumber,
            content: content ?? "",
            correspondent: correspondent?.name,
            createdDate: DateFormatter.createdDate.string(from: createdDate),
            customFields: customFields.compactMap { row in
                // Resolved through the cache, matching how `DocumentFormInput` reads definitions
                // everywhere else.
                guard let field = row.id.get(server), let value = row.value.promptValue else {
                    return nil
                }
                return TitleSuggestionContext.CustomFieldValue(label: field.name, value: value)
            },
            documentType: documentType?.name,
            storagePath: storagePath?.name,
            tags: tags.map(\.name).sorted(),
            title: title
        )
    }
}
