import ApiInterface
import Components
import ComposableArchitecture
import SwiftUI

struct DocumentFilterSortField: View {
    var body: some View {
        Field(.sort) {
            ZStack {
                content()
                Menu {
                    ForEach(SortDirection.allCases, id: \.self) { direction in
                        Button {
                            send(.sortDirectionButtonTapped(direction))
                        } label: {
                            Label {
                                Text(direction.localized)
                            } icon: {
                                Image(systemName: direction.systemImage)
                            }
                        }
                    }

                    Divider()

                    ForEach(SortField.allCases, id: \.self) { field in
                        Button {
                            send(.sortFieldButtonTapped(field))
                        } label: {
                            Text(field.localized)
                        }
                    }
                } label: {
                    content()
                        .opacity(0)
                }
            }
        }
    }

    init(
        direction: SortDirection,
        field: SortField,
        onViewAction: @escaping (DocumentFilterReducer.Action.View) -> StoreTask
    ) {
        self.direction = direction
        self.field = field
        self.onViewAction = onViewAction
    }

    @ViewBuilder
    private func content() -> some View {
        HStack(spacing: .x3) {
            Image(systemName: direction.systemImage)
                .font(.title2)
                .foregroundStyle(Color.m3Primary)
            Text(field.localized).capsule()
            Spacer()
        }
    }

    @discardableResult
    private func send(_ action: DocumentFilterReducer.Action.View) -> StoreTask {
        onViewAction(action)
    }

    private let direction: SortDirection

    private let field: SortField

    private let onViewAction: (DocumentFilterReducer.Action.View) -> StoreTask
}

private extension SortDirection {

    var localized: LocalizedStringResource {
        switch self {
        case .ascending:
            .sortDirectionAscending
        case .descending:
            .sortDirectionDescending
        }
    }

    var systemImage: String {
        switch self {
        case .ascending:
            "arrow.down.circle"
        case .descending:
            "arrow.up.circle"
        }
    }
}

private extension SortField {

    var localized: LocalizedStringResource {
        switch self {
        case .added:
            .sortFieldAdded
        case .asn:
            .sortFieldAsn
        case .correspondent:
            .sortFieldCorrespondent
        case .created:
            .sortFieldCreated
        case .documentType:
            .sortFieldDocumentType
        case .modified:
            .sortFieldModified
        case .notes:
            .sortFieldNotes
        case .owner:
            .sortFieldOwner
        case .title:
            .sortFieldTitle
        }
    }
}
