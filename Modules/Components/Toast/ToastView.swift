import SwiftUI

public struct ToastView: View {

    public var body: some View {
        HStack(spacing: .x4) {
            Image(systemName: toast.imageName)
                .font(.title)
                .fontWeight(.light)
            Text(toast.message)
                .font(.body)
                .fontWeight(.medium)
            Spacer()
        }
        .padding(.x4)
        .frame(maxWidth: .infinity)
        .background(toast.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
        .foregroundStyle(toast.foregroundColor)
        .padding(.x4)
        .frame(maxWidth: 600)
    }

    public init(
        toast: Toast
    ) {
        self.toast = toast
    }

    public let toast: Toast
}

#Preview {
    ToastView(toast: .success("YAY\n\\\\o//"))
    ToastView(toast: .error("NAY\n//o\\\\"))
}
