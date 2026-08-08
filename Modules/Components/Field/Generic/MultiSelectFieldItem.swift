import SwiftUI

public struct MultiSelectFieldItem: View {

    public var body: some View {
        Text(value.description)
            .capsule()
    }

    public init(value: CustomStringConvertible) {
        self.value = value
    }

    private let value: CustomStringConvertible
}
