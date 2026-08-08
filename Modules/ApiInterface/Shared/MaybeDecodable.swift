import Foundation

public struct MaybeDecodable<T: Decodable>: Decodable {

    public let error: Error?

    public let wrapped: T?

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        do {
            wrapped = try container.decode(T.self)
            error = nil
        } catch {
            wrapped = nil
            self.error = error
        }
    }
}
