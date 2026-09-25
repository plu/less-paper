import SwiftUI

public extension Color {
    static let m3Error = Color.internalM3Error
    static let m3ErrorContainer = Color.internalM3ErrorContainer
    static let m3InverseSurface = Color.internalM3InverseSurface
    static let m3OnError = Color.internalM3OnError
    static let m3OnErrorContainer = Color.internalM3OnErrorContainer
    static let m3OnInverseSurface = Color.internalM3OnInverseSurface
    static let m3OnPrimary = Color.internalM3OnPrimary
    static let m3OnPrimaryContainer = Color.internalM3OnPrimaryContainer
    static let m3OnSecondary = Color.internalM3OnSecondary
    static let m3OnSecondaryContainer = Color.internalM3OnSecondaryContainer
    static let m3OnSurface = Color.internalM3OnSurface
    static let m3OnSurfaceVariant = Color.internalM3OnSurfaceVariant
    static let m3OnTertiary = Color.internalM3OnTertiary
    static let m3OnTertiaryContainer = Color.internalM3OnTertiaryContainer
    static let m3Outline = Color.internalM3Outline
    static let m3OutlineVariant = Color.internalM3OutlineVariant
    static let m3Primary = Color.internalM3Primary
    static let m3PrimaryContainer = Color.internalM3PrimaryContainer
    static let m3Secondary = Color.internalM3Secondary
    static let m3SecondaryContainer = Color.internalM3SecondaryContainer
    static let m3Shadow = Color.internalM3Shadow
    static let m3Surface = Color.internalM3Surface
    static let m3SurfaceBright = Color.internalM3SurfaceBright
    static let m3SurfaceContainer = Color.internalM3SurfaceContainer
    static let m3SurfaceContainerHigh = Color.internalM3SurfaceContainerHigh
    static let m3SurfaceContainerHighest = Color.internalM3SurfaceContainerHighest
    static let m3SurfaceContainerLow = Color.internalM3SurfaceContainerLow
    static let m3SurfaceContainerLowest = Color.internalM3SurfaceContainerLowest
    static let m3SurfaceDim = Color.internalM3SurfaceDim
    static let m3Tertiary = Color.internalM3Tertiary
    static let m3TertiaryContainer = Color.internalM3TertiaryContainer
}

// Not `m3`-prefixed, because these are not Material roles. The scheme has roles for *how bright* a
// surface is, and both of the things below need a role for *what it means* — which inverts against
// brightness between the themes, so no `m3` symbol can carry either one.
//
// The field states run grey → near-white → white in light and near-black → calm grey → lighter grey
// in dark. Both run the same direction, more light as a field becomes more usable, but light spends
// the top of its range on the caret while dark spends the bottom of its range on a locked field.
// `m3SurfaceBright` would have to be the resting fill in light and the focused fill in dark at the
// same time.
//
// The sheet header wants one polarity in both themes, a dark brand teal under light type, and
// `m3Primary` and `m3PrimaryContainer` invert in opposite directions — aliasing either flips the
// bar in whichever theme it was not chosen for.
//
// A swipe action wants the same thing for the same reason, and cannot even ask nicely: the system
// draws the button's label itself, in white, whatever the label view says — verified by tinting one
// yellow and watching it come out white anyway. That makes the tint the only lever, so `m3Primary`
// — a deep teal in light and a bright mint in dark — puts white on mint the moment the theme flips.
// `m3Error` does the same, dark red to a pale pink.
//
// `onSwipeAction` is that system white. Nothing sets it; it is named so the pair it has to survive
// can be contrast-checked beside every other pair rather than taken on trust.
//
// The missing prefix is the signal: an `m3` symbol is a role the Material scheme could regenerate,
// these are app decisions that no generator will ever produce.
public extension Color {
    static let fieldFill = Color.internalFieldFill
    static let fieldFillFocused = Color.internalFieldFillFocused
    static let fieldFillReadOnly = Color.internalFieldFillReadOnly
    static let onSheetHeader = Color.internalOnSheetHeader
    static let onSwipeAction = Color.internalOnSwipeAction
    static let sheetHeader = Color.internalSheetHeader
    static let swipeAction = Color.internalSwipeAction
    static let swipeActionDestructive = Color.internalSwipeActionDestructive
}

public extension Color {

    struct ColorPreview: View {
        let backgroundColor: Color
        let backgroundName: String
        let foregroundColor: Color
        let foregroundName: String

        public var body: some View {
            VStack(alignment: .leading) {
                Text(backgroundName)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.horizontal)
                Text(foregroundName)
                    .foregroundStyle(foregroundColor)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding()
                    .background(backgroundColor)
                    .border(Color.m3Outline)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    @MainActor
    static let previewValue: some View = {
        VStack(alignment: .leading) {
            ColorPreview(
                backgroundColor: .m3Surface,
                backgroundName: "m3Surface",
                foregroundColor: .m3OnSurface,
                foregroundName: "m3OnSurface"
            )

            ColorPreview(
                backgroundColor: .m3SurfaceBright,
                backgroundName: "m3SurfaceBright",
                foregroundColor: .m3OnSurface,
                foregroundName: "m3OnSurface"
            )

            ColorPreview(
                backgroundColor: .m3SurfaceDim,
                backgroundName: "m3SurfaceDim",
                foregroundColor: .m3OnSurface,
                foregroundName: "m3OnSurface"
            )

            ColorPreview(
                backgroundColor: .m3SurfaceContainerLowest,
                backgroundName: "m3SurfaceContainerLowest",
                foregroundColor: .m3OnSurface,
                foregroundName: "m3OnSurface"
            )

            ColorPreview(
                backgroundColor: .m3SurfaceContainerLow,
                backgroundName: "m3SurfaceContainerLow",
                foregroundColor: .m3OnSurface,
                foregroundName: "m3OnSurface"
            )

            ColorPreview(
                backgroundColor: .m3SurfaceContainer,
                backgroundName: "m3SurfaceContainer",
                foregroundColor: .m3OnSurface,
                foregroundName: "m3OnSurface"
            )

            ColorPreview(
                backgroundColor: .m3SurfaceContainerHigh,
                backgroundName: "m3SurfaceContainerHigh",
                foregroundColor: .m3OnSurface,
                foregroundName: "m3OnSurface"
            )

            ColorPreview(
                backgroundColor: .m3SurfaceContainerHighest,
                backgroundName: "m3SurfaceContainerHighest",
                foregroundColor: .m3OnSurface,
                foregroundName: "m3OnSurface"
            )

            ColorPreview(
                backgroundColor: .m3Error,
                backgroundName: "m3Error",
                foregroundColor: .m3OnError,
                foregroundName: "m3OnError"
            )

            ColorPreview(
                backgroundColor: .m3ErrorContainer,
                backgroundName: "m3ErrorContainer",
                foregroundColor: .m3OnErrorContainer,
                foregroundName: "m3OnErrorContainer"
            )

            ColorPreview(
                backgroundColor: .m3Primary,
                backgroundName: "m3Primary",
                foregroundColor: .m3OnPrimary,
                foregroundName: "m3OnPrimary"
            )

            ColorPreview(
                backgroundColor: .m3PrimaryContainer,
                backgroundName: "m3PrimaryContainer",
                foregroundColor: .m3OnPrimaryContainer,
                foregroundName: "m3OnPrimaryContainer"
            )

            ColorPreview(
                backgroundColor: .m3Secondary,
                backgroundName: "m3Secondary",
                foregroundColor: .m3OnSecondary,
                foregroundName: "m3OnSecondary"
            )

            ColorPreview(
                backgroundColor: .m3SecondaryContainer,
                backgroundName: "m3SecondaryContainer",
                foregroundColor: .m3OnSecondaryContainer,
                foregroundName: "m3OnSecondaryContainer"
            )

            ColorPreview(
                backgroundColor: .m3Surface,
                backgroundName: "m3Surface",
                foregroundColor: .m3OnSurface,
                foregroundName: "m3OnSurface"
            )

            ColorPreview(
                backgroundColor: .m3InverseSurface,
                backgroundName: "m3InverseSurface",
                foregroundColor: .m3OnInverseSurface,
                foregroundName: "m3OnInverseSurface"
            )

            ColorPreview(
                backgroundColor: .m3Tertiary,
                backgroundName: "m3Tertiary",
                foregroundColor: .m3OnTertiary,
                foregroundName: "m3OnTertiary"
            )

            ColorPreview(
                backgroundColor: .m3TertiaryContainer,
                backgroundName: "m3TertiaryContainer",
                foregroundColor: .m3OnTertiaryContainer,
                foregroundName: "m3OnTertiaryContainer"
            )

            ColorPreview(
                backgroundColor: .m3Surface,
                backgroundName: "m3Surface",
                foregroundColor: .m3OnSurfaceVariant,
                foregroundName: "m3OnSurfaceVariant"
            )

            ColorPreview(
                backgroundColor: .m3Outline,
                backgroundName: "m3Outline",
                foregroundColor: .clear,
                foregroundName: ""
            )

            ColorPreview(
                backgroundColor: .m3OutlineVariant,
                backgroundName: "m3OutlineVariant",
                foregroundColor: .clear,
                foregroundName: ""
            )

            ColorPreview(
                backgroundColor: .m3Shadow,
                backgroundName: "m3Shadow",
                foregroundColor: .clear,
                foregroundName: ""
            )

            ColorPreview(
                backgroundColor: .sheetHeader,
                backgroundName: "sheetHeader",
                foregroundColor: .onSheetHeader,
                foregroundName: "onSheetHeader"
            )

            ColorPreview(
                backgroundColor: .swipeAction,
                backgroundName: "swipeAction",
                foregroundColor: .onSwipeAction,
                foregroundName: "onSwipeAction"
            )

            ColorPreview(
                backgroundColor: .swipeActionDestructive,
                backgroundName: "swipeActionDestructive",
                foregroundColor: .onSwipeAction,
                foregroundName: "onSwipeAction"
            )

            ColorPreview(
                backgroundColor: .fieldFillReadOnly,
                backgroundName: "fieldFillReadOnly",
                foregroundColor: .m3OnSurface,
                foregroundName: "m3OnSurface"
            )

            ColorPreview(
                backgroundColor: .fieldFill,
                backgroundName: "fieldFill",
                foregroundColor: .m3OnSurface,
                foregroundName: "m3OnSurface"
            )

            ColorPreview(
                backgroundColor: .fieldFillFocused,
                backgroundName: "fieldFillFocused",
                foregroundColor: .m3OnSurface,
                foregroundName: "m3OnSurface"
            )
        }
        .frame(minWidth: 300)
    }()
}

#Preview {
    ScrollView {
        Color.previewValue
            .frame(maxWidth: .infinity, alignment: .topLeading)
    }
    .frame(maxWidth: .infinity, alignment: .topLeading)
}

public extension Color {

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let alpha, red, green, blue: UInt64
        switch hex.count {
        case 3:
            (alpha, red, green, blue) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (alpha, red, green, blue) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (alpha, red, green, blue) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (alpha, red, green, blue) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: Double(alpha) / 255
        )
    }

    var hexValue: String {
        guard let components = cgColor?.components else {
            return "#ffffff"
        }

        let red = components[0]
        let green = components[1]
        let blue = components[2]
        let multiplier = CGFloat(255.999999)

        return String(
            format: "#%02lX%02lX%02lX",
            Int(red * multiplier),
            Int(green * multiplier),
            Int(blue * multiplier)
        )
    }
}
