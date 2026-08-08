import ApiInterface
import Components
import ComposableArchitecture
import SwiftUI

struct DocumentFilterGenericValueListView<Value: CustomStringConvertible & Equatable & Hashable & Identifiable & Sendable>: View {
    var body: some View {
        Sheet(isScrollingEnabled: false, padding: .x0) {
            SheetHeader(
                title: title,
                left: leftHeader
            )
        } content: {
            VStack(spacing: .x4) {
                sectionPicker()
                sectionView()
            }
        }
    }

    @Bindable
    var store: StoreOf<DocumentFilterGenericValueListReducer<Value>>

    let title: LocalizedStringResource

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
        Button {
            store.send(.view(.closeButtonTapped))
        } label: {
            Image(systemName: "xmark")
                .accessibilityLabel(.close)
        }
    }

    @ViewBuilder
    private func list() -> some View {
        Searchable {
            List(store.filteredValues) { value in
                Button {
                    store.send(.view(.valueTapped(value)))
                } label: {
                    HStack(spacing: .x4) {
                        Image(systemName: systemImage(value))
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.m3Outline)
                        Text(value.description)
                            .font(.body)
                            .foregroundStyle(Color.m3OnSurface)
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
            ForEach(DocumentFilterGenericValueRule.allCases, id: \.self) {
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
        case .exclude, .include:
            list()
        case .notAssigned:
            Spacer()
        }
    }

    private func systemImage(_ value: Value) -> String {
        switch store.rule {
        case .exclude:
            if store.selection.contains(value) {
                "xmark.circle.fill"
            } else {
                "circle"
            }
        case .include:
            if store.selection.contains(value) {
                "checkmark.circle.fill"
            } else {
                "circle"
            }
        case .notAssigned:
            preconditionFailure()
        }
    }
}
