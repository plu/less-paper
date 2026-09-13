import DesignTokens
import SwiftUI

// Drawn as the same card DocumentRowView draws, because "a list row rather than a banner" only
// means anything if it is indistinguishable from the rows around it. The call site supplies the
// `.padding(.x3)` and the clear listRowBackground that the document lists give every row.
public struct TipInvitationBanner: View {

    public var body: some View {
        HStack(alignment: .top, spacing: .x4) {
            Image(systemName: "cup.and.saucer")
                .imageScale(.large)
                .foregroundStyle(Color.m3Primary)
                // Purely decorative, and would otherwise read out as "cup and saucer" ahead of the
                // card's actual accessible content below.
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: .x2) {
                Text(.tipInvitationTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.m3OnSurface)

                Text(.tipInvitationMessage)
                    .font(.footnote)
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

            Button {
                dismissed()
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(Color.m3Primary)
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
