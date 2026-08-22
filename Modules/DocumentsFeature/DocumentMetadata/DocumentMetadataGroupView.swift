import Components
import SwiftUI

struct DocumentMetadataGroupView: View {

    struct Row: Equatable, Identifiable {

        var id: String { "\(title.key)-\(value ?? "")" }

        let isMonospaced: Bool

        let title: LocalizedStringResource

        let value: String?

        init(
            title: LocalizedStringResource,
            value: String?,
            isMonospaced: Bool = false
        ) {
            self.isMonospaced = isMonospaced
            self.title = title
            self.value = value
        }
    }

    var body: some View {
        // A row the server has nothing for is dropped rather than shown as a dash: the card then
        // says only what is true of this document.
        let rows = rows.filter { !($0.value ?? "").isEmpty }

        if !rows.isEmpty {
            // Header above the card rather than inside it, the shape PermissionsFormView uses for
            // Change and View.
            VStack(alignment: .leading, spacing: .x0) {
                Text(title)
                    .fontWeight(.semibold)
                    .padding(.horizontal)

                VStack(alignment: .leading) {
                    ForEach(rows) { row in
                        rowView(row: row)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(RoundedRectangle(cornerRadius: Constants.cornerRadius).foregroundStyle(Color.m3SurfaceContainer))
            }
        }
    }

    let rows: [Row]

    let title: LocalizedStringResource

    @ViewBuilder
    private func rowView(row: Row) -> some View {
        // The same Field the forms use, with a Text where they put a control: nothing here is
        // editable, and the label belongs in the capsule rather than opposite the value.
        Field(row.title) {
            Text(row.value ?? "")
                .font(row.isMonospaced ? .body.monospaced() : .body)
                .foregroundStyle(Color.m3OnSurface)
                .lineLimit(1)
                // Middle rather than tail: the tail of a checksum or a filename is the half that
                // tells two of them apart.
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement()
        .accessibilityLabel(Text(row.title))
        .accessibilityValue(row.value ?? "")
    }
}

#Preview {
    DocumentMetadataGroupView(
        rows: [
            .init(title: .filename, value: "TonieBox.pdf"),
            .init(title: .size, value: "327 KB"),
            .init(title: .checksum, value: "65990b5f69b2fcc4e24bf93340721ea8cfef2f36a0f2b87deb5b80344caa861f", isMonospaced: true),
        ],
        title: .original
    )
    .padding()
}
