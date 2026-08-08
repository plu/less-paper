import SwiftUI

struct SingleSelectOptions<Value: Comparable & CustomStringConvertible & Hashable & Identifiable>: View {

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
                ScrollViewReader { proxy in
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
                    .searchable(text: $searchText)
                    .onAppear {
                        if let selection {
                            withAnimation {
                                proxy.scrollTo(selection.id, anchor: .top)
                            }
                        }
                    }
                }
            }
        }
    }

    init(
        clearable: Bool,
        isPresented: Binding<Bool>,
        options: [Value],
        selection: Binding<Value?>,
        title: LocalizedStringResource,
        onCreate: (() -> Void)? = nil
    ) {
        self._isPresented = isPresented
        self._selection = selection
        self.clearable = clearable
        self.onCreate = onCreate
        self.options = options
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
        selection?.id == value.id ? "checkmark.circle.fill" : "circle"
    }

    private func toggle(_ value: Value) {
        if selection != value {
            selection = value
        } else if clearable {
            selection = nil
        }
    }

    private var filteredOptions: [Value] {
        if searchText.isEmpty {
            options
        } else {
            options.filter { $0.description.localizedCaseInsensitiveContains(searchText) }
        }
    }

    private let clearable: Bool

    @Binding
    private var isPresented: Bool

    private let onCreate: (() -> Void)?

    private let options: [Value]

    @State
    private var searchText = ""

    private let title: LocalizedStringResource

    @Binding
    private var selection: Value?
}
