import DesignTokens
import SwiftUI

public struct MultiSelectOptionsItem: View {

    public var body: some View {
        Text(value.description)
            .font(.body)
            .foregroundStyle(Color.m3OnSurface)
    }

    public init(value: CustomStringConvertible) {
        self.value = value
    }

    private let value: CustomStringConvertible
}
