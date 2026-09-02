import ApiInterface
import Components
import ComposableArchitecture
import DesignTokens
import SwiftUI

@ViewAction(for: DocumentFilterDateReducer.self)
struct DocumentFilterDateView: View {
    var body: some View {
        Sheet(isScrollingEnabled: false, padding: .x0) {
            SheetHeader(
                title: .date,
                left: leftHeader
            )
        } content: {
            VStack(spacing: .x4) {
                typePicker()
                bounds()
                Spacer()
            }
        }
    }

    @Bindable
    var store: StoreOf<DocumentFilterDateReducer>

    @ViewBuilder
    private func leftHeader() -> some View {
        SheetCloseButton {
            send(.closeButtonTapped)
        }
    }

    @ViewBuilder
    private func typePicker() -> some View {
        Picker("", selection: $store.date.type) {
            ForEach(DocumentFilterDateType.allCases, id: \.self) {
                Text($0.localized)
            }
        }
        .labelsHidden()
        .padding(.horizontal, .x4)
        .padding(.top, .x4)
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private func bounds() -> some View {
        VStack(spacing: .x0) {
            bound(
                title: .from,
                date: $store.date.from.date,
                onSet: { send(.fromButtonTapped) },
                onReset: { send(.resetFromButtonTapped) }
            )
            Divider()
            bound(
                title: .to,
                date: $store.date.to.date,
                onSet: { send(.toButtonTapped) },
                onReset: { send(.resetToButtonTapped) }
            )
        }
        .padding(.horizontal, .x4)
    }

    @ViewBuilder
    private func bound(
        title: LocalizedStringResource,
        date: Binding<Date?>,
        onSet: @escaping () -> Void,
        onReset: @escaping () -> Void
    ) -> some View {
        HStack(spacing: .x3) {
            Text(title)
                .foregroundStyle(Color.m3OnSurface)

            Spacer()

            if let value = date.wrappedValue {
                // An overlay rather than a ZStack sibling: a ZStack takes the width of its widest
                // child, so the invisible picker decided how wide the visible capsule was - and a
                // compact DatePicker's intrinsic width is not stable from one day to the next, so
                // the capsule silently changed width as the date rolled over. As an overlay it is
                // laid out inside the capsule, which leaves the visible text deciding the size and
                // the tap target exactly the capsule.
                Text(DateFormatter.filterRule.string(from: value))
                    .capsule()
                    .overlay {
                        DatePicker(
                            "",
                            selection: Binding(
                                get: { value },
                                set: { date.wrappedValue = $0 }
                            ),
                            displayedComponents: .date
                        )
                        .labelsHidden()
                        .blendMode(.destinationOver)
                    }

                Button(action: onReset) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.m3Outline)
                }
                .accessibilityLabel(.reset)
            } else {
                Button(action: onSet) {
                    Text(.any).capsule()
                }
            }
        }
        .frame(minHeight: 44)
    }
}

#Preview {
    DocumentFilterDateView(
        store: Store(
            initialState: DocumentFilterDateReducer.State(),
            reducer: {
                DocumentFilterDateReducer()
            }
        )
    )
}
