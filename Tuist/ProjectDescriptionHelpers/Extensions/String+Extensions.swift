import Foundation
import ProjectDescription

extension String {
    // Set dynamic build number only when building app/IPA. For selective tests,
    // use static value since environment variables affect test cache hashing.
    static let buildNumber = Environment.buildIpa.getBoolean(default: false)
        ? [
            Environment.githubRunNumber.getString()
        ].compactMap(\.self).joined(separator: ".")
        : "1"

    static let marketingVersion = "3.0.2"
}
