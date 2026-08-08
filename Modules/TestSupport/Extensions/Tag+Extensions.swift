#if canImport(Testing)

import Testing

public extension Tag {

    @Tag
    static var integrationTests: Self

    @Tag
    static var snapshotTests: Self
}

#endif
