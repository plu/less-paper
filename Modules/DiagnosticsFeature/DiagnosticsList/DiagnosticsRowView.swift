import Components
import Logging
import SwiftUI

struct DiagnosticsRowView: View {

    let entry: LogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: .x1) {
            HStack(spacing: .x2) {
                Text(entry.level.rawValue)
                    .foregroundStyle(levelColor)
                Text(entry.category.rawValue)
                    .foregroundStyle(Color.m3OnSurface.opacity(0.6))
                Spacer()
                Text(entry.date, format: .dateTime.day().month().hour().minute().second())
                    .foregroundStyle(Color.m3OnSurface.opacity(0.6))
            }
            .font(.caption2)
            .fontWeight(.medium)

            Text(entry.message)
                .font(.footnote)
                .monospaced()
                .foregroundStyle(Color.m3OnSurface)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, .x1)
    }

    private var levelColor: Color {
        switch entry.level {
        case .error: .m3Error
        case .warning: .m3Tertiary
        case .info: .m3Primary
        }
    }
}
