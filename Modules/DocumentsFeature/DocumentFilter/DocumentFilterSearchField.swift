import ApiInterface
import Components
import ComposableArchitecture
import SwiftUI

struct DocumentFilterSearchField: View {
    var body: some View {
        Field(searchType.localized) {
            HStack(spacing: .x3) {
                Menu {
                    ForEach(DocumentFilterSearchType.allCases) { searchType in
                        switch searchType {
                        case .asn:
                            Menu {
                                ForEach(DocumentFilterASNType.allCases) { asnType in
                                    Button {
                                        send(.asnTypeButtonTapped(asnType))
                                    } label: {
                                        Text(asnType.localized)
                                    }
                                }
                            } label: {
                                Text(searchType.localized)
                            }
                        default:
                            Button {
                                send(.searchTypeButtonTapped(searchType))
                            } label: {
                                Text(searchType.localized)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "magnifyingglass.circle")
                }
                .font(.title2)
                .tint(Color.m3Primary)

                AdaptiveStack {
                    switch searchType {
                    case .asn:
                        switch asnType {
                        case .equals, .greaterThan, .lowerThan:
                            Text(asnType.localized)
                                .capsule()
                            TextField(String(localized: searchType.localized), text: $searchValue)
                                .textFieldStyle(.plain)
                                .keyboardType(.numberPad)
                        case .isEmpty, .isNotEmpty:
                            Text(asnType.localized)
                                .capsule()
                            Spacer()
                        }
                    default:
                        TextField(String(localized: searchType.localized), text: $searchValue)
                            .textFieldStyle(.plain)
                    }
                }
            }
        }
    }

    init(
        asnType: DocumentFilterASNType,
        onViewAction: @escaping (DocumentFilterReducer.Action.View) -> StoreTask,
        searchType: DocumentFilterSearchType,
        searchValue: Binding<String>
    ) {
        self.asnType = asnType
        self.onViewAction = onViewAction
        self.searchType = searchType
        self._searchValue = searchValue
    }

    @discardableResult
    private func send(_ action: DocumentFilterReducer.Action.View) -> StoreTask {
        onViewAction(action)
    }

    @Binding
    private var searchValue: String

    private let asnType: DocumentFilterASNType
    private let onViewAction: (DocumentFilterReducer.Action.View) -> StoreTask
    private let searchType: DocumentFilterSearchType
}
