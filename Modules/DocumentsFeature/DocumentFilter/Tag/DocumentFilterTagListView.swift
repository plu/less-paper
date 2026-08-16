import ApiInterface
import Components
import ComposableArchitecture
import SwiftUI

@ViewAction(for: DocumentFilterTagListReducer.self)
struct DocumentFilterTagListView: View {
    var body: some View {
        Sheet(isScrollingEnabled: false, padding: .x0) {
            SheetHeader(
                title: .tag,
                left: leftHeader
            )
        } content: {
            VStack(spacing: .x4) {
                sectionPicker()
                sectionView()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: .x0) {
            DocumentFilterMatchCountView()
        }
    }

    @Bindable
    var store: StoreOf<DocumentFilterTagListReducer>

    @ViewBuilder
    private func emptyListView() -> some View {
        if store.filteredValues.isEmpty {
            ContentUnavailableView {
                EmptyListView(systemImage: "tray")
            }
        }
    }

    @ViewBuilder
    private func leftHeader() -> some View {
        SheetCloseButton {
            send(.closeButtonTapped)
        }
    }

    @ViewBuilder
    private func list() -> some View {
        Searchable {
            List(store.filteredValues) { value in
                Button {
                    send(.valueTapped(value))
                } label: {
                    HStack(spacing: .x4) {
                        Image(systemName: systemImage(value))
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.m3Outline)
                        Text(value.description)
                            .capsule(
                                backgroundColor: Color(hex: value.color),
                                font: .body,
                                foregroundColor: Color(hex: value.textColor)
                            )
                    }
                }
                .foregroundStyle(Color.m3OnSurface)
                .id(value.id)
                .listRowBackground(Color.m3Surface)
                .listRowInsets(EdgeInsets(top: .x4, leading: .x4, bottom: .x3, trailing: .x4))
                .listRowSeparator(.hidden)
            }
            .background(Color.m3Surface)
            .environment(\.defaultMinListRowHeight, 0)
            .listStyle(.plain)
            .navigationBarHidden(true)
            .overlay(emptyListView())
            .presentationDetents([.sheet])
            .scrollContentBackground(.hidden)
            .searchable(text: $store.searchText)
        }
    }

    @ViewBuilder
    private func sectionPicker() -> some View {
        Picker("", selection: $store.rule) {
            ForEach(DocumentFilterTagRule.allCases, id: \.self) {
                Text($0.localized)
            }
        }
        .labelsHidden()
        .padding(.horizontal, .x4)
        .padding(.top, .x4)
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private func sectionView() -> some View {
        switch store.rule {
        case .all, .any:
            list()
        case .assigned, .notAssigned:
            Spacer()
        }
    }

    private func systemImage(_ value: Tag) -> String {
        switch store.rule {
        case .all:
            if store.selection.all.include.contains(value) {
                "checkmark.circle.fill"
            } else if store.selection.all.exclude.contains(value) {
                "xmark.circle.fill"
            } else {
                "circle"
            }
        case .any:
            if store.selection.any.contains(value) {
                "checkmark.circle.fill"
            } else {
                "circle"
            }
        case .assigned, .notAssigned:
            preconditionFailure()
        }
    }
}
