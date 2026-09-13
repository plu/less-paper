import DesignTokens
import SwiftUI

// The same card DocumentRowView draws - fill, radius, insets - but outlined in `m3Primary` rather
// than `m3OutlineVariant`, so it sits in the stack as a list row while still being the one card on
// screen that is asking for attention. The call site supplies the `.padding(.x3)` and the clear
// listRowBackground that the document lists give every row.
public struct TipInvitationBanner: View {

    public var body: some View {
        HStack(alignment: .top, spacing: .x4) {
            // An inner centred row so the mug sits against the middle of the text while the close
            // button stays at the top. Centring the outer stack would drag the button down with it,
            // and `.frame(maxHeight: .infinity)` on the mug would make this stack as greedy as its
            // greediest child and balloon the card to whatever height its container proposes.
            HStack(alignment: .center, spacing: .x4) {
                Image(systemName: "cup.and.saucer")
                    .imageScale(.large)
                    .foregroundStyle(Color.m3Primary)
                    // Purely decorative, and would otherwise read out as "cup and saucer" ahead of
                    // the card's actual accessible content below.
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
            }
            // Without this, VoiceOver reads the mug, title and message as separate, non-interactive
            // elements and never reaches `tapped()` - the card's entire purpose. Combining them into
            // one button-trait element, with its own explicit action, is what makes the tip jar
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
        // `strokeBorder`, not `stroke`: the clipShape below trims anything outside the rounded
        // rectangle, and a centred stroke puts half its width there - so a 2pt `stroke` would
        // render as 1pt. `strokeBorder` insets the line so the whole 2pt survives the clip.
        .overlay(RoundedRectangle(cornerRadius: Constants.cornerRadius).strokeBorder(Color.m3Primary, lineWidth: 2))
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
