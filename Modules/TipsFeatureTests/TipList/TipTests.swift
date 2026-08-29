import Testing
import TipsFeature

@Suite
struct TipTests {

    // These ids are permanent: App Store Connect will not let one be renamed or reused, so a typo
    // here is a product id abandoned forever. That is what this test is guarding.
    @Test
    func productIdsAreExact() {
        #expect(Tip.small.rawValue == "com.aptumtek.app.Paperless.tip.small")
        #expect(Tip.medium.rawValue == "com.aptumtek.app.Paperless.tip.medium")
        #expect(Tip.large.rawValue == "com.aptumtek.app.Paperless.tip.large")
    }

    // The order is the ladder shown on screen, not whatever StoreKit hands back.
    @Test
    func casesAreOrderedSmallestFirst() {
        #expect(Tip.allCases == [.small, .medium, .large])
    }
}
