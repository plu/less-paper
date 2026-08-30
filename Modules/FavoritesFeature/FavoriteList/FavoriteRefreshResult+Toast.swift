import ApiInterface
import Components
import Foundation

extension FavoriteRefreshResult {

    // What a manual refresh reports. Only the first thing worth saying is said: a failure is what
    // the user can act on, a document the server no longer has is news the row badge only shows
    // once the list is looked at, and everything else is the ordinary case. The automatic refresh
    // in AppFeature deliberately reports none of this.
    var toast: Toast {
        if failed > 0 {
            return .error(String(localized: .favoritesRefreshFailed(failed)))
        }
        if unavailable > 0 {
            return .error(String(localized: .favoritesRefreshUnavailable(unavailable)))
        }
        if updated > 0 {
            return .success(String(localized: .favoritesRefreshUpdated(updated)))
        }
        return .success(String(localized: .favoritesUpToDate))
    }
}
