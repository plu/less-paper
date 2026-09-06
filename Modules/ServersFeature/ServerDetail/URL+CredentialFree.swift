import Foundation

extension URL {

    // absoluteString is never what this screen renders: a server URL can carry userinfo -
    // https://user:s3cr3t@paperless.example.com:8000 is a real configuration behind a proxy that
    // does HTTP basic auth, and ServerFormInput.isValid accepts it because host is still set - and
    // absoluteString round-trips the password intact. This screen is the one people screenshot when
    // they ask for help, so it prints the parts that identify the server and nothing else.
    //
    // Rebuilt from an empty URLComponents rather than by nilling user and password on the parsed
    // ones: a whitelist cannot be outlived by a component someone adds later, and query and
    // fragment are dropped along the way - neither belongs to a server address, and either could
    // carry a token.
    //
    // nil rather than a fallback to absoluteString when the URL cannot be taken apart: the caller
    // renders that as Unknown, and an unparseable URL is exactly the case where guessing would put
    // the credentials back on screen.
    var credentialFreeDisplayString: String? {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return nil
        }

        var stripped = URLComponents()
        stripped.scheme = components.scheme
        stripped.host = components.host
        stripped.port = components.port
        stripped.path = components.path

        return stripped.string
    }
}
