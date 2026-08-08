import SwiftUI

public struct MultiSelectField<
    FieldItemView: View,
    OptionsItemView: View,
    Value: Comparable & CustomStringConvertible & Hashable & Identifiable
>: View {
    public var body: some View {
        Field(title) {
            ScrollView(.horizontal) {
                LazyHStack {
                    ForEach(Array(selection).sorted()) { value in
                        fieldItem(value)
                    }
                }
            }
        }
        .onTapGesture {
            isPresentingOptions = true
        }
        .sheet(isPresented: $isPresentingOptions) {
            MultiSelectOptions(
                isPresented: $isPresentingOptions,
                options: options,
                selection: $selection,
                title: title,
                onCreate: onCreate,
                optionsItem: optionsItem
            )
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityElement()
        .accessibilityLabel(title)
        .accessibilityValue(selection.map(\.description).sorted().joined(separator: ", "))
    }

    public init(
        options: [Value],
        selection: Binding<Set<Value>>,
        title: LocalizedStringResource,
        onCreate: (() -> Void)? = nil,
        @ViewBuilder fieldItem: @escaping (Value) -> FieldItemView,
        @ViewBuilder optionsItem: @escaping (Value) -> OptionsItemView
    ) {
        self._selection = selection
        self.fieldItem = fieldItem
        self.onCreate = onCreate
        self.options = options
        self.optionsItem = optionsItem
        self.title = title
    }

    @State
    var isPresentingOptions = false

    private let fieldItem: (Value) -> FieldItemView

    private let onCreate: (() -> Void)?

    private let options: [Value]

    private let optionsItem: (Value) -> OptionsItemView

    private let title: LocalizedStringResource

    @Binding
    private var selection: Set<Value>
}

public extension MultiSelectField where FieldItemView == MultiSelectFieldItem, OptionsItemView == MultiSelectOptionsItem {

    init(
        options: [Value],
        selection: Binding<Set<Value>>,
        title: LocalizedStringResource,
        onCreate: (() -> Void)? = nil
    ) {
        self._selection = selection
        self.fieldItem = { MultiSelectFieldItem(value: $0) }
        self.onCreate = onCreate
        self.options = options
        self.optionsItem = { MultiSelectOptionsItem(value: $0) }
        self.title = title
    }
}

struct MultiSelectFieldPreview: View {
    @Observable
    final class Model {
        var options = [
            Value(description: "John"),
            Value(description: "Jane"),
            Value(description: "Rick"),
            Value(description: "Rita")
        ]
        var selection = Set<Value>()
    }

    struct Value: Comparable, CustomStringConvertible, Equatable, Hashable, Identifiable {
        static func < (lhs: MultiSelectFieldPreview.Value, rhs: MultiSelectFieldPreview.Value) -> Bool {
            lhs.description < rhs.description
        }

        var id: String { description }
        let description: String
    }

    @Bindable
    var model = Model()

    var body: some View {
        ScrollView {
            MultiSelectField(
                options: model.options,
                selection: $model.selection,
                title: "Select"
            )
            .padding()
        }
    }
}

#Preview {
    MultiSelectFieldPreview()
}
