import SwiftUI

public struct MenuField<SelectionValue: CaseIterable & CustomStringConvertible & Hashable & Identifiable>: View {

    public var body: some View {
        Field(title) {
            HStack {
                Picker("", selection: $value) {
                    ForEach(Array(SelectionValue.allCases), id: \.self) { value in
                        Text(value.description)
                            .id(value.id)
                    }
                }
                .pickerStyle(.menu)
                .tint(.m3OnSurface)
                .offset(x: -12)

                Spacer()
            }
        }
    }

    public init(
        title: LocalizedStringResource?,
        value: Binding<SelectionValue>
    ) {
        self.title = title
        self._value = value
    }

    private let title: LocalizedStringResource?

    @Binding
    private var value: SelectionValue
}
