import Foundation

// The API pair cannot be reused here. JSONEncoder.apiEncoder formats every Date as "yyyy-MM-dd",
// which is right for the API — paperless wants a day for `created` — and wrong for a file we read
// back. It would round `storedAt` to midnight, and round `document.modified` with it: the field the
// refresh gate compares, which would then differ from the server's on every launch and re-download
// every PDF. Nothing has hit this before because `documents(_:)` is `.inMemory`, so no Document has
// ever been written to disk.
public extension JSONEncoder {

    static let favoritesEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return encoder
    }()
}

public extension JSONDecoder {

    static let favoritesDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }()
}
