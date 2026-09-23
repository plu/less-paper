import SwiftUI

public struct ToastView: View {

    public struct Action {
        public let title: String
        public let handler: () -> Void

        public init(
            title: String,
            handler: @escaping () -> Void
        ) {
            self.title = title
            self.handler = handler
        }
    }

    public var body: some View {
        HStack(spacing: .x4) {
            Image(systemName: toast.imageName)
                .font(.title)
                .fontWeight(.light)
            Text(toast.message)
                .font(.body)
                .fontWeight(.medium)
                // Only when a button shares the row: the button sizes to its title and wins the
                // contest for the slack, so without this the message wraps with room to spare.
                // Left to the trailing Spacer otherwise, which is what every toast without an
                // action has always laid out with.
                .frame(maxWidth: action == nil ? nil : .infinity, alignment: .leading)
            if let action {
                Button(action.title, action: action.handler)
                    .font(.body)
                    .fontWeight(.bold)
                    // .plain keeps the label in the toast's foregroundStyle; the default tint would
                    // paint it accent blue on both container colours.
                    .buttonStyle(.plain)
                    // The row is only as tall as one line of body text, which leaves the button
                    // short of the 44pt target on its own.
                    .padding(.vertical, .x2)
                    .contentShape(Rectangle())
                    .layoutPriority(1)
            } else {
                Spacer()
            }
        }
        .padding(.x4)
        .frame(maxWidth: .infinity)
        .background(toast.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
        .foregroundStyle(toast.foregroundColor)
        .padding(.x4)
        .frame(maxWidth: 600)
        // children: .contain keeps the message queryable as a descendant rather than flattening it
        // into one label, so a journey can still assert on toast copy.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("Toast")
    }

    public init(
        toast: Toast,
        action: Action? = nil
    ) {
        self.toast = toast
        self.action = action
    }

    public let toast: Toast

    private let action: Action?
}

#Preview {
    ToastView(toast: .success("YAY\n\\\\o//"))
    ToastView(toast: .error("NAY\n//o\\\\"))
    ToastView(
        toast: .success("Removed 2 inbox tags"),
        action: .init(title: "Undo") {}
    )
}
