import SwiftUI

public struct URLField: View {
    public var body: some View {
        Field(title, padding: .x0) {
            HStack(spacing: .x0) {
                Picker(.scheme, selection: $scheme) {
                    ForEach(Scheme.allCases, id: \.self) { scheme in
                        Text(scheme.displayValue)
                            .id(scheme.rawValue)
                    }
                }
                .dynamicTypeSize(.xSmall ... .accessibility1)
                .labelsHidden()
                .pickerStyle(.menu)
                .tint(.m3OnSurface)

                TextField(String(localized: .domain), text: $address)
                    .autocorrectionDisabled()
                    .textFieldStyle(.plain)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .padding(.trailing, .x2)
            }
        }
        .onChange(of: address, updateUrl)
        .onChange(of: scheme, updateUrl)
    }

    public init(
        title: LocalizedStringResource? = nil,
        url: Binding<URL>
    ) {
        self.title = title
        self._url = url
        address = url.wrappedValue.absoluteString
            .replacingOccurrences(of: "\(url.wrappedValue.scheme ?? "")://", with: "")
            .replacingOccurrences(of: "about:blank", with: "")
        scheme = .init(rawValue: url.wrappedValue.scheme)
    }

    private func updateUrl() {
        if let url = URLComponents(string: "\(scheme.displayValue)\(address)")?.url {
            self.url = url
        }
    }

    private let title: LocalizedStringResource?

    @State
    private var address = ""

    @State
    private var scheme: Scheme

    @Binding
    private var url: URL

    private enum Scheme: String, CaseIterable {
        case https, http

        var displayValue: String {
            "\(rawValue)://"
        }

        init(rawValue: String?) {
            if let rawValue {
                self = .init(rawValue: rawValue) ?? .https
            } else {
                self = .https
            }
        }
    }
}

#Preview {
    @Previewable
    @State
    var url = URL(string: "https://www.google.com:8443/foo")!

    ScrollView {
        VStack(spacing: .x5) {
            URLField(
                title: LocalizedStringResource("URL"),
                url: $url
            )
            Text(url.absoluteString)
            Spacer()
        }
        .padding()
    }
}
