import ApiInterface
import Components
import ComposableArchitecture
import SwiftUI

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

    private var bounds: String {
        let formatter = DateFormatter.filterRule
        let from = date.from.date.map(formatter.string(from:)) ?? String(localized: .any)
        let to = date.to.date.map(formatter.string(from:)) ?? String(localized: .any)
        return "\(from) – \(to)"
    }
}
