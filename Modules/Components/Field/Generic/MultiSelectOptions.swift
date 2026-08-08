import SwiftUI

struct MultiSelectOptions<OptionsItemView: View, Value: Comparable & CustomStringConvertible & Hashable & Identifiable>: View {

    var body: some View {
        Sheet(isScrollingEnabled: false, padding: .x0) {
            SheetHeader(
                title: title,
                left: {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                            .accessibilityLabel(.close)
                    }
                },
                right: {
                    if let onCreate {
                        Button {
                            isPresented = false
                            onCreate()
                        } label: {
                            Image(systemName: "plus")
                                .accessibilityLabel(.add(item: String(localized: title)))
                        }
                    }
                }
            )
        } content: {
            Searchable {
                List(filteredOptions) { value in
                    Button {
                        withAnimation(.snappy) {
                            toggle(value)
                        }
                    } label: {
                        HStack(spacing: .x4) {
                            Image(systemName: systemImage(value))
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.m3Outline)
                            optionsItem(value)
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
                .searchable(text: $searchText)
            }
        }
    }

    init(
        isPresented: Binding<Bool>,
        options: [Value],
        selection: Binding<Set<Value>>,
        title: LocalizedStringResource,
        onCreate: (() -> Void)? = nil,
        @ViewBuilder optionsItem: @escaping (Value) -> OptionsItemView
    ) {
        self._isPresented = isPresented
        self._selection = selection
        self.onCreate = onCreate
        self.options = options
        self.optionsItem = optionsItem
        self.title = title
    }

    @ViewBuilder
    private func emptyListView() -> some View {
        if options.isEmpty {
            ContentUnavailableView {
                EmptyListView(systemImage: "tray")
            }
        }
    }

    private func systemImage(_ value: Value) -> String {
        selection.contains(where: { $0.id == value.id })
            ? "checkmark.circle.fill"
            : "circle"
    }

    private func toggle(_ value: Value) {
        if selection.contains(value) {
            selection.remove(value)
        } else {
            selection.insert(value)
        }
    }

    private var filteredOptions: [Value] {
        if searchText.isEmpty {
            options
        } else {
            options.filter { $0.description.localizedCaseInsensitiveContains(searchText) }
        }
    }

    @Binding
    private var isPresented: Bool

    private let onCreate: (() -> Void)?

    private let options: [Value]

    @ViewBuilder
    private let optionsItem: (Value) -> OptionsItemView

    @State
    private var searchText = ""

    @Binding
    private var selection: Set<Value>

    private let title: LocalizedStringResource
}

extension MultiSelectOptions where OptionsItemView == MultiSelectOptionsItem {
    init(
        isPresented: Binding<Bool>,
        options: [Value],
        selection: Binding<Set<Value>>,
        title: LocalizedStringResource,
        onCreate: (() -> Void)? = nil
    ) {
        self.init(
            isPresented: isPresented,
            options: options,
            selection: selection,
            title: title,
            onCreate: onCreate,
            optionsItem: MultiSelectOptionsItem.init(value:)
        )
    }
}
