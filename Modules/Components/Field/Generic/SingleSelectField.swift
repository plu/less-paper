import Combine
import DesignTokens
import IssueReporting
import SwiftUI

public struct SingleSelectField<Value: Comparable & CustomStringConvertible & Hashable & Identifiable>: View {

    public var body: some View {
        Field(title) {
            HStack {
                if let selection {
                    Text(selection.description)
                } else {
                    Color.clear
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(Color.m3OnSurface)
            .font(.body)
        }
        .onTapGesture {
            isPresentingOptions = true
        }
        .sheet(isPresented: $isPresentingOptions) {
            SingleSelectOptions(
                clearable: clearable,
                isPresented: $isPresentingOptions,
                options: options,
                selection: $selection,
                title: title,
                onCreate: onCreate
            )
        }
        .onChange(of: selection) {
            if dismissOnSelection {
                isPresentingOptions = false
            }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityElement()
        .accessibilityLabel(title)
        .accessibilityValue(selection?.description ?? "")
    }

    public init(
        dismissOnSelection: Bool = true,
        options: [Value],
        selection: Binding<Value?>,
        title: LocalizedStringResource,
        onCreate: (() -> Void)? = nil
    ) {
        self._selection = selection
        self.clearable = true
        self.dismissOnSelection = dismissOnSelection
        self.onCreate = onCreate
        self.options = options
        self.title = title
    }

    public init(
        dismissOnSelection: Bool = true,
        options: [Value],
        selection: Binding<Value>,
        title: LocalizedStringResource,
        onCreate: (() -> Void)? = nil
    ) {
        _selection = Binding<Value?>(
            get: { selection.wrappedValue },
            set: { newValue in
                if let newValue {
                    selection.wrappedValue = newValue
                } else {
                    reportIssue("SingleSelectField: Assigning nil to non-optional @Binding is not allowed.")
                }
            }
        )
        self.clearable = false
        self.dismissOnSelection = dismissOnSelection
        self.onCreate = onCreate
        self.options = options
        self.title = title
    }

    @State
    var isPresentingOptions = false

    private let clearable: Bool

    private let dismissOnSelection: Bool

    private let onCreate: (() -> Void)?

    private let options: [Value]

    private let title: LocalizedStringResource

    @Binding
    private var selection: Value?
}

struct SingleSelectFieldPreview: View {
    @Observable
    final class Model {
        var options = [
            Value(description: "John"),
            Value(description: "Jane"),
            Value(description: "Rick"),
            Value(description: "Rita")
        ]
        var selection: Value?
    }

    struct Value: Comparable, CustomStringConvertible, Equatable, Hashable, Identifiable {
        static func < (lhs: SingleSelectFieldPreview.Value, rhs: SingleSelectFieldPreview.Value) -> Bool {
            lhs.description < rhs.description
        }

        var id: String { description }
        let description: String
    }

    @Bindable
    var model = Model()

    var body: some View {
        ScrollView {
            SingleSelectField(
                options: model.options,
                selection: $model.selection,
                title: "Select"
            )
            .padding()
        }
    }
}

#Preview {
    SingleSelectFieldPreview()
}
