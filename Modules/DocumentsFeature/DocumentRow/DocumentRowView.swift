import ApiInterface
import Components
import ComposableArchitecture
import Dependencies
import ImageFeature
import QuickLook
import SwiftUI

@ViewAction(for: DocumentRowReducer.self)
struct DocumentRowView: View {
    var body: some View {
        AdaptiveStack(
            breakpoint: breakpoint,
            horizontalAlignment: .center,
            horizontalSpacing: .x0,
            verticalSpacing: .x0
        ) {
            imageView()
            detailsView()
        }
        .sheet(item: $store.shareItem) { item in
            ShareSheet(url: item.url)
        }
        .frame(maxWidth: .infinity)
        .background(Color.m3SurfaceContainer)
        .buttonStyle(.borderless)
        .contentShape(Rectangle())
        .listRowSeparator(.hidden)
        .onTapGesture { send(.rowTapped) }
        .overlay(RoundedRectangle(cornerRadius: Constants.cornerRadius).stroke(Color.m3OutlineVariant, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
        .contextMenu(menuItems: contextMenu)
        .opacity(store.isBusy ? 0.5 : 1.0)
        // After the opacity, so the spinner is not dimmed along with the row beneath it.
        .overlay { downloadProgressView() }
        .quickLookPreview($store.quickLookPreview)
        .sheet(
            item: $store.scope(state: \.destination?.documentForm, action: \.destination.documentForm)
        ) { store in
            DocumentFormView(store: store)
                .presentationDetents([.large])
        }
    }

    @Bindable
    var store: StoreOf<DocumentRowReducer>

    @ViewBuilder
    private func contextMenu() -> some View {
        Button {
            send(.previewButtonTapped)
        } label: {
            Label(.preview, systemImage: "eye")
        }

        Button {
            send(.shareButtonTapped)
        } label: {
            Label(.share, systemImage: "square.and.arrow.up")
        }

        Button {
            send(.editButtonTapped)
        } label: {
            Label(.edit, systemImage: "square.and.pencil")
        }

        Button(role: .destructive) {
            send(.deleteButtonTapped)
        } label: {
            Label(.delete, systemImage: "trash")
        }
    }

    @ViewBuilder
    private func detailsView() -> some View {
        VStack(alignment: .leading, spacing: .x3) {
            AdaptiveStack(
                horizontalSpacing: .x2,
                verticalAlignment: .top
            ) {
                Text(store.correspondent)
                    .font(.footnote)
                    .fontWeight(.bold)
                    .foregroundColor(.m3Primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if sizeCategory < .accessibilityMedium {
                    Spacer(minLength: 0)
                }
                Text(DateFormatter.createdDate.string(from: store.document.created))
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundColor(.m3Outline)
                    .lineLimit(1)
                    .padding(.trailing, .x2)
            }
            Text(store.document.title)
                .fixedSize(horizontal: false, vertical: true)
                .font(.body)
                .foregroundColor(.m3OnSurface)
                .lineLimit(store.titleLineLimit)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            Grid(alignment: .leading, horizontalSpacing: .x2) {
                if let asn = store.document.archiveSerialNumber {
                    GridRow {
                        Image(systemName: "barcode").accessibilityHidden(true)
                        Text(String(asn)).lineLimit(1)
                    }
                }
                if let documentTypeName = store.documentType {
                    GridRow {
                        Image(systemName: "doc").accessibilityHidden(true)
                        Text(documentTypeName).lineLimit(1)
                    }
                }
                if let storagePathName = store.storagePath {
                    GridRow {
                        Image(systemName: "folder").accessibilityHidden(true)
                        Text(storagePathName).lineLimit(1)
                    }
                }
            }
        }
        .foregroundColor(.m3Outline)
        .fontWeight(.medium)
        .font(.footnote)
        .padding(sizeCategory >= breakpoint ? .x4 : .x3)
    }

    @ViewBuilder
    private func downloadProgressView() -> some View {
        if store.isDownloading {
            ProgressView()
                .controlSize(.large)
        }
    }

    @ViewBuilder
    private func imageView() -> some View {
        DocumentImage(
            document: store.document.id,
            server: store.server,
            size: imageSize
        )
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: Constants.cornerRadius).stroke(Color.m3OutlineVariant, lineWidth: 1))
        .overlay(alignment: .topTrailing) {
            tagsView()
        }
        .padding(.top, sizeCategory >= breakpoint ? .x4 : .x0)
        .padding(.horizontal, sizeCategory >= breakpoint ? .x4 : .x0)
    }

    @ViewBuilder
    private func tagsView() -> some View {
        VStack(alignment: .trailing, spacing: .x2) {
            ForEach(store.tags) { tag in
                Text(tag.name)
                    .capsule(
                        backgroundColor: Color(hex: tag.color),
                        font: .footnote,
                        foregroundColor: Color(hex: tag.textColor)
                    )
            }
        }
        .frame(height: imageSize.height - .x4, alignment: .top)
        .clipped()
        .padding(.x3)
    }

    private let breakpoint = ContentSizeCategory.extraLarge

    private var imageSize: CGSize {
        CGSize(width: 134 * scaleFactor, height: 190 * scaleFactor)
    }

    @ScaledMetric
    private var scaleFactor = 1.0

    @Environment(\.sizeCategory)
    private var sizeCategory
}

#Preview {
    List {
        DocumentRowView(
            store: Store(
                initialState: DocumentRowReducer.State.testValue(),
                reducer: {
                    DocumentRowReducer()
                }
            )
        )

        DocumentRowView(
            store: Store(
                initialState: DocumentRowReducer.State.testValue(document: .testValue(tags: Array(repeating: 1, count: 20))),
                reducer: {
                    DocumentRowReducer()
                }
            )
        )

        ForEach(ContentSizeCategory.allCases, id: \.self) { sizeCategory in
            Section(String(describing: sizeCategory)) {
                DocumentRowView(
                    store: Store(
                        initialState: DocumentRowReducer.State.testValue(),
                        reducer: {
                            DocumentRowReducer()
                        }
                    )
                )
                .environment(\.sizeCategory, sizeCategory)
            }
        }
    }
    .background(Color.m3SurfaceContainerLowest)
    .listStyle(.plain)
    .navigationBarTitleDisplayMode(.inline)
    .scrollContentBackground(.hidden)
}
