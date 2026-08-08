import ApiInterface
import Components
import Foundation
import Tagged

public struct SavedViewFormInput: Equatable, Sendable {

    var filterRules: [FilterRule] = []

    var name = FieldState(focused: true, value: "")

    var owner: Clearable<User.Id>?

    var setPermissions: Permissions?

    var showInSidebar = false

    var showOnDashboard = false

    var sortDirection = SortDirection.descending

    var sortField = SortField.added
}

public extension SavedViewFormInput {
    init(filterRules: [FilterRule] = []) {
        self.filterRules = filterRules
    }

    static func testValue(
        filterRules: [FilterRule] = [],
        name: FieldState<String> = FieldState(focused: false, value: "Test SavedView"),
        owner: Clearable<User.Id>? = nil,
        setPermissions: Permissions? = nil,
        showInSidebar: Bool = false,
        showOnDashboard: Bool = false,
        sortDirection: SortDirection = .descending,
        sortField: SortField = .added
    ) -> Self {
        .init(
            filterRules: filterRules,
            name: name,
            owner: owner,
            setPermissions: setPermissions,
            showInSidebar: showInSidebar,
            showOnDashboard: showOnDashboard,
            sortDirection: sortDirection,
            sortField: sortField
        )
    }
}

extension SavedViewFormInput {
    init(savedView: SavedView?) {
        if let savedView {
            self.init(
                filterRules: savedView.filterRules,
                name: .init(value: savedView.name),
                showInSidebar: savedView.showInSidebar,
                showOnDashboard: savedView.showOnDashboard,
                sortDirection: savedView.sortDirection,
                sortField: savedView.sortField
            )
        } else {
            self.init()
        }
    }

    var apiValue: SaveSavedViewInput {
        .init(
            filterRules: filterRules,
            name: name.value,
            owner: owner,
            setPermissions: setPermissions,
            sortField: sortField,
            sortReverse: sortDirection.sortReverse
        )
    }

    mutating func applyFieldErrors(from apiError: ApiError) {
        for (fieldName, keyPath) in SavedViewFormField.fieldStateKeyPaths {
            if let error = apiError.errorForField(fieldName.rawValue) {
                self[keyPath: keyPath] = error
            }
        }
    }
}
