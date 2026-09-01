import DesignTokens
import SwiftUI

struct DateSuggestions: View {

    @Binding
    var suggestions: [CreatedDate]

    @Binding
    var value: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(.suggestions)
                .dynamicTypeSize(.xSmall ... .accessibility2)
                .fontWeight(.medium)

            List {
                Group {
                    Text(.today)
                        .onTapGesture {
                            value = Calendar.current.startOfDay(for: Date())
                        }

                    ForEach(suggestions) { suggestion in
                        Text(DateFormatter.createdDate.string(from: suggestion.date))
                            .onTapGesture {
                                value = suggestion.date
                            }
                    }
                }
                .dynamicTypeSize(.xSmall ... .accessibility2)
                .font(.body)
                .foregroundColor(Color.m3Primary)
                .listRowBackground(Color.m3Surface)
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .background(Color.m3Surface)
            .frame(maxWidth: .infinity, minHeight: 120)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}
