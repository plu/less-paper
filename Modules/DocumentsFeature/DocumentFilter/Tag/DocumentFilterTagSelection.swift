import ApiInterface

public struct DocumentFilterTagSelection: Equatable {

    struct All: Equatable {

        var exclude = Set<Tag>()

        var include = Set<Tag>()
    }

    var all = All()

    var any = Set<Tag>()
}

extension DocumentFilterTagSelection.All {
    static func testValue(
        exclude: Set<Tag> = [],
        include: Set<Tag> = []
    ) -> Self {
        .init(
            exclude: exclude,
            include: include
        )
    }
}

extension DocumentFilterTagSelection {
    static func testValue(
        all: All = .testValue(),
        any: Set<Tag> = []
    ) -> Self {
        .init(
            all: all,
            any: any
        )
    }
}
