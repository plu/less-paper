import DesignTokens
import SwiftUI

// Drawn as the same card DocumentRowView draws, because "a list row rather than a banner" only
// means anything if it is indistinguishable from the rows around it. The call site supplies the
// `.padding(.x3)` and the clear listRowBackground that the document lists give every row.
public struct TipInvitationBanner: View {

    public var body: some View {
        HStack(alignment: .top, spacing: .x4) {
            Image(systemName: "cup.and.saucer")
                .foregroundStyle(Color.m3OnSurface)

            VStack(alignment: .leading, spacing: .x2) {
                Text(.tipInvitationTitle)
                    .font(.body)
                    .foregroundStyle(Color.m3OnSurface)

                Text(.tipInvitationMessage)
                    .font(.subheadline)
                    .foregroundStyle(Color.m3Outline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                dismissed()
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(Color.m3Outline)
            }
            .accessibilityLabel(.tipInvitationDismiss)
            .buttonStyle(.borderless)
        }
        .padding(.x4)
        .frame(maxWidth: .infinity)
        .background(Color.m3SurfaceContainer)
        .contentShape(Rectangle())
        .onTapGesture { tapped() }
        .overlay(RoundedRectangle(cornerRadius: Constants.cornerRadius).stroke(Color.m3OutlineVariant, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
    }

    public init(
        tapped: @escaping () -> Void,
        dismissed: @escaping () -> Void
    ) {
        self.tapped = tapped
        self.dismissed = dismissed
    }

    private let tapped: () -> Void
    private let dismissed: () -> Void
}
