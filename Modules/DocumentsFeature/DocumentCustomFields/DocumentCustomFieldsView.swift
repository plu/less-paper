import ApiInterface
import Components
import ComposableArchitecture
import SwiftUI

@ViewAction(for: DocumentCustomFieldsReducer.self)
struct DocumentCustomFieldsView: View {

    var body: some View {
        content()
            .onAppear { send(.onAppear) }
    }

    @Bindable
    var store: StoreOf<DocumentCustomFieldsReducer>

    @ViewBuilder
    private func content() -> some View {
        // Emptiness is judged on what will actually render, not on what is attached: a document
        // carrying nothing but blank fields would otherwise show an empty screen with no
        // explanation.
        let rows = renderableRows()

        if rows.isEmpty {
            EmptyListView(
                systemImage: "list.bullet.rectangle",
                title: .noCustomFieldsAttached
            )
            // Only the empty state fills the sheet, so it centres. The populated case sizes to its
            // content and lets the scroll view move it.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                // One card holding every field in document order, links included: a link rendered
                // outside it read as a different kind of thing rather than another field.
                VStack(alignment: .leading) {
                    ForEach(rows) { row in
                        rowView(row)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: Constants.cornerRadius)
                        .foregroundStyle(Color.m3SurfaceContainerLow)
                )
                // The sheet passes no padding for this section so the scroll view reaches the
                // edges; the inset belongs to the content instead.
                .padding(.x4)
            }
            // Inside a NavigationStack a ScrollView paints the system grouped background, which is
            // white over the sheet's m3Surface.
            .scrollContentBackground(.hidden)
        }
    }

    private func renderableRows() -> [DocumentCustomFieldRow] {
        store.rows.filter { row in
            if case let .documentLink(ids) = row.value {
                return !ids.isEmpty
            }
            guard let definition = row.definition else {
                return false
            }
            return row.value?.displayValue(field: definition) != nil
        }
    }

    @ViewBuilder
    private func rowView(_ row: DocumentCustomFieldRow) -> some View {
        if case let .documentLink(ids) = row.value {
            // One Field per linked document rather than one Field holding all of them: Field clips
            // to a capsule and offsets its input upward to tuck a single line under the floating
            // label, so a second line inside it collides with the border.
            ForEach(ids, id: \.self) { id in
                Field(.init(stringLiteral: row.name)) {
                    linkLine(id: id)
                }
                .readOnly()
            }
        } else {
            // The same Field the forms and the metadata card use, so a single-valued custom field
            // reads exactly like a metadata row.
            Field(.init(stringLiteral: row.name)) {
                Text(row.definition.flatMap { row.value?.displayValue(field: $0) } ?? "")
                    .foregroundStyle(Color.m3OnSurface)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .readOnly()
        }
    }

    // A line rather than a capsule: stacked capsules fight the Field's own capsule outline, and
    // every other field in the card renders its value as plain text. Tinting is what says the line
    // leads somewhere.
    @ViewBuilder
    private func linkLine(id: Document.Id) -> some View {
        if let document = store.linkedDocuments[id: id] {
            Button {
                send(.documentLinkTapped(id))
            } label: {
                HStack {
                    Text(document.title)
                        .foregroundStyle(Color.m3Primary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.right")
                        .foregroundStyle(Color.m3Outline)
                        .imageScale(.small)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
        } else {
            // An unresolved link has no document to open, so it stays inert — and carries no
            // chevron, which would promise a destination that is not there yet.
            Text(verbatim: "#\(id.rawValue)")
                .foregroundStyle(Color.m3Outline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
