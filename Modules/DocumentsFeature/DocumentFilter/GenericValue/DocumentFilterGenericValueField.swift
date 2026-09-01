import ApiInterface
import Components
import ComposableArchitecture
import DesignTokens
import SwiftUI

struct DocumentFilterGenericValueField<Value: Comparable & CustomStringConvertible & Equatable & Hashable & Identifiable & Sendable>: View {

    let rule: DocumentFilterGenericValueRule

    let selection: Set<Value>

    let systemImage: String

    let title: LocalizedStringResource

    var body: some View {
        Field(title) {
            HStack(spacing: .x3) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(Color.m3Primary)
                switch rule {
                case .exclude, .include:
                    if selection.isEmpty {
                        Text(.any).capsule()
                        Spacer()
                    } else {
                        ScrollView(.horizontal) {
                            LazyHStack(spacing: .x3) {
                                ForEach(selection.sorted()) { value in
                                    Text(value.description)
                                        .capsule()
                                        .strikethrough(rule == .exclude)
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                    }
                case .notAssigned:
                    Text(.notAssigned).capsule()
                    Spacer()
                }
            }
        }
    }
}
