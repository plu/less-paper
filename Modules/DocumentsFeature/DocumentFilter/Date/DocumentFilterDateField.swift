import ApiInterface
import Components
import ComposableArchitecture
import SwiftUI

/// The filter sheet's date row.
///
/// One row that opens a sheet, like the correspondent, document type, storage path and tag fields
/// — a date range is a multi-value editor, not a one-tap choice.
struct DocumentFilterDateField: View {

    let date: DocumentFilterInput.DateFilter

    var body: some View {
        Field(.date) {
            HStack(spacing: .x3) {
                Image(systemName: "calendar.circle")
                    .font(.title2)
                    .foregroundStyle(Color.m3Primary)

                if date.from.date == nil, date.to.date == nil {
                    Text(.any).capsule()
                } else {
                    Text(date.type.localized).capsule()
                    Text(bounds).capsule()
                }

                Spacer()
            }
        }
    }

    /// The range as `from – to`, with an en dash and an open end where a bound is unset.
    private var bounds: String {
        let formatter = DateFormatter.filterRule
        let from = date.from.date.map(formatter.string(from:)) ?? String(localized: .any)
        let to = date.to.date.map(formatter.string(from:)) ?? String(localized: .any)
        return "\(from) – \(to)"
    }
}
