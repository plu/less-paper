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
                // Purely decorative, and would otherwise read out as "cup and saucer" ahead of the
                // card's actual accessible content below.
                .accessibilityHidden(true)

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
            // Without this, VoiceOver reads the title and message as two separate, non-interactive
            // static texts and never reaches `tapped()` - the card's entire purpose. Combining them
            // into one button-trait element, with its own explicit action, is what makes the tip jar
            // reachable; it does not depend on this element sharing a hit-testing region with the
            // `.onTapGesture` below, which is what makes it correct regardless of layout changes.
            // The close button keeps its own separate element and label, set on it directly below.
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { tapped() }

            // Top-aligned like the icon rather than `.frame(maxHeight: .infinity)`-centered: the
            // latter makes an HStack's cross-axis size as greedy as its greediest child, which
            // balloons the whole card to fill whatever height its container happens to propose
            // (harmless inside a list row sized to its own content, but not when the banner is
            // snapshotted on its own). Its own trailing space keeps it from crowding Dismiss.
            Image(systemName: "chevron.right")
                .foregroundStyle(Color.m3Outline)
                .padding(.trailing, .x2)
                // Redundant with the isButton trait on the text above; would otherwise add a third,
                // unlabelled element between it and Dismiss.
                .accessibilityHidden(true)

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
