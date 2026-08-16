import SwiftUI

struct DateFieldPopover: View {

    let title: LocalizedStringResource

    @Binding
    var value: Date

    @Binding
    var suggestions: [CreatedDate]

    var body: some View {
        Sheet(isScrollingEnabled: false, padding: .x0) {
            SheetHeader(
                title: title,
                left: {
                    SheetCloseButton {
                        dismiss()
                    }
                }
            )
        } content: {
            VStack(alignment: .leading, spacing: .x3) {
                DatePicker(title, selection: $value, displayedComponents: .date)
                    .datePickerStyle(.graphical).labelsHidden()
                    .padding(.horizontal, .x3)
                    .frame(idealWidth: 320)

                Divider()

                DateSuggestions(
                    suggestions: $suggestions,
                    value: $value
                )
                .padding(.horizontal, .x3)
            }
        }
        .presentationDetents([.fraction(0.85)])
    }

    @Environment(\.dismiss)
    private var dismiss
}
