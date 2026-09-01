import ApiInterface
import Components
import DesignTokens
import SwiftUI

// The option list gets its own sheet rather than sitting inline in the editor: a select field can
// carry more options than a `Field` capsule has room for, and this matches how tags are chosen.
struct CustomFieldQuerySelectOptionsView: View {

    let field: CustomField?

    let onViewAction: (CustomFieldQueryAtomEditorReducer.Action.View) -> Void

    let selected: Set<String>

    var body: some View {
        Sheet(isScrollingEnabled: false, padding: .x0) {
            SheetHeader(title: title, left: closeButton)
        } content: {
            list()
        }
    }

    private var options: [CustomFieldSelectOption] {
        field?.extraData?.selectOptions ?? []
    }

    private var title: LocalizedStringResource {
        guard let field else {
            return .value
        }
        return .init(stringLiteral: field.name)
    }

    @ViewBuilder
    private func closeButton() -> some View {
        SheetCloseButton {
            onViewAction(.optionsDismissed)
        }
    }

    @ViewBuilder
    private func list() -> some View {
        List(options, id: \.label) { option in
            row(option)
        }
        .background(Color.m3Surface)
        .environment(\.defaultMinListRowHeight, 0)
        .listStyle(.plain)
        .overlay(emptyListView())
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private func row(_ option: CustomFieldSelectOption) -> some View {
        let id = option.id ?? ""

        Button {
            onViewAction(.optionToggled(id))
        } label: {
            HStack(spacing: .x4) {
                Image(systemName: selected.contains(id) ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.m3Outline)
                Text(option.label)
                    .font(.body)
                    .foregroundStyle(Color.m3OnSurface)
            }
        }
        .foregroundStyle(Color.m3OnSurface)
        .listRowBackground(Color.m3Surface)
        .listRowInsets(EdgeInsets(top: .x4, leading: .x4, bottom: .x3, trailing: .x4))
        .listRowSeparator(.hidden)
    }

    @ViewBuilder
    private func emptyListView() -> some View {
        if options.isEmpty {
            ContentUnavailableView {
                EmptyListView(systemImage: "tray")
            }
        }
    }
}
