@testable import SettingsFeature

import Foundation
import Testing

@MainActor
@Suite
struct SettingListLinksTests {

    // The two halves that are silently wrong rather than broken: a mistyped id opens a stranger's
    // App Store page, and a missing action opens ours on the description instead of the sheet the
    // row promises. Both still open something, so nothing else here would notice.
    @Test
    func reviewUrl_opensTheWriteAReviewSheetForThisApp() {
        let url = SettingListView.reviewUrl

        #expect(url.host() == "apps.apple.com")
        #expect(url.lastPathComponent == "id6464425056")
        #expect(url.query() == "action=write-review")
    }
}
