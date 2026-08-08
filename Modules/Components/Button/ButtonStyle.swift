import SwiftUI

public struct ButtonStyle: SwiftUI.ButtonStyle {

    let isLoading: Binding<Bool>

    let size: ButtonSize

    let type: ButtonType

    public func makeBody(configuration: ButtonStyle.Configuration) -> some View {
        ButtonView(
            configuration: configuration,
            isLoading: isLoading,
            style: self
        )
    }

    struct ButtonView: View {

        let configuration: ButtonStyle.Configuration

        @Binding
        var isLoading: Bool

        let style: ButtonStyle

        var body: some View {
            Group {
                ZStack {
                    configuration.label
                        .opacity(isLoading ? 0 : 1)
                        .labelStyle(ButtonLabelStyle())
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .opacity(isLoading ? 1 : 0)
                        .tint(foregroundColor)
                    #if os(macOS)
                        .controlSize(.small)
                    #endif
                }
            }
            .font(Font.body.weight(.semibold))
            .foregroundColor(foregroundColor)
            .frame(height: height)
            .padding(.horizontal, style.size.horizontalPadding)
            .background(background)
            .contentShape(Capsule())
            .clipShape(Capsule())
            .allowsHitTesting(!isLoading)
        }

        private var background: some View {
            style.type.background(
                style,
                configuration: configuration,
                isEnabled: isEnabled,
                scaledMetric: scaledMetric
            )
        }

        private var foregroundColor: Color {
            style.type.foregroundColor(style, configuration: configuration, isEnabled: isEnabled)
        }

        private var height: CGFloat {
            if verticalSizeClass == .compact {
                return scaledMetric * ButtonSize.small.height
            }
            return scaledMetric * style.size.height
        }

        @Environment(\.isEnabled)
        private var isEnabled: Bool

        @ScaledMetric
        private var scaledMetric: Double = 1.0

        @Environment(\.verticalSizeClass)
        private var verticalSizeClass
    }
}

private struct ButtonLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.icon
            configuration.title
        }
    }
}

extension ButtonType {

    @ViewBuilder
    func background(
        _ style: ButtonStyle,
        configuration: ButtonStyle.Configuration,
        isEnabled: Bool,
        scaledMetric: Double
    ) -> some View {
        if !isEnabled {
            Capsule()
                .strokeBorder(style.type.borderColorDisabled, lineWidth: 2 * scaledMetric)
                .background(
                    RoundedRectangle(cornerRadius: style.size.cornerRadius)
                        .foregroundColor(style.type.backgroundColorDisabled)
                )
        } else if configuration.isPressed {
            Capsule()
                .strokeBorder(style.type.borderColorPressed, lineWidth: 2 * scaledMetric)
                .background(
                    RoundedRectangle(cornerRadius: style.size.cornerRadius)
                        .foregroundColor(style.type.backgroundColorPressed)
                )
        } else {
            Capsule()
                .strokeBorder(style.type.borderColor, lineWidth: 2 * scaledMetric)
                .background(
                    RoundedRectangle(cornerRadius: style.size.cornerRadius)
                        .foregroundColor(style.type.backgroundColor)
                )
        }
    }

    func foregroundColor(
        _ style: ButtonStyle,
        configuration: ButtonStyle.Configuration,
        isEnabled: Bool
    ) -> Color {
        if !isEnabled {
            style.type.titleColorDisabled
        } else if configuration.isPressed {
            style.type.titleColorPressed
        } else {
            style.type.titleColor
        }
    }
}

public extension SwiftUI.ButtonStyle where Self == ButtonStyle {

    static func primary(
        isLoading: Binding<Bool> = .constant(false),
        size: ButtonSize = .regular
    ) -> ButtonStyle {
        ButtonStyle(
            isLoading: isLoading,
            size: size,
            type: .primary
        )
    }

    static func secondary(
        isLoading: Binding<Bool> = .constant(false),
        size: ButtonSize = .regular
    ) -> ButtonStyle {
        ButtonStyle(
            isLoading: isLoading,
            size: size,
            type: .secondary
        )
    }

    static func ghost(
        isLoading: Binding<Bool> = .constant(false),
        size: ButtonSize = .regular
    ) -> ButtonStyle {
        ButtonStyle(
            isLoading: isLoading,
            size: size,
            type: .ghost
        )
    }

    static func critical(
        isLoading: Binding<Bool> = .constant(false),
        size: ButtonSize = .regular
    ) -> ButtonStyle {
        ButtonStyle(
            isLoading: isLoading,
            size: size,
            type: .critical
        )
    }
}
