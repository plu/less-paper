import SwiftUI

public struct DateField: View {

    public var body: some View {
        Field(title) {
            HStack {
                Text(DateFormatter.createdDate.string(from: value))
                Spacer()
            }
        }.onTapGesture {
            isPresentingPopover = true
        }.popover(isPresented: $isPresentingPopover, arrowEdge: .bottom) {
            DateFieldPopover(
                title: title,
                value: $value,
                suggestions: $suggestions
            )
        }
        .buttonStyle(.plain)
    }

    public init(
        title: LocalizedStringResource,
        value: Binding<Date>,
        suggestions: Binding<[CreatedDate]>
    ) {
        self.title = title
        _value = value
        _suggestions = suggestions
    }

    private let title: LocalizedStringResource

    @Binding
    private var value: Date

    @Binding
    private var suggestions: [CreatedDate]

    @State
    private var isPresentingPopover = false
}
