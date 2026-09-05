import Testing
import TipsFeature

@Suite
struct TipTests {

    // These ids are permanent: App Store Connect will not let one be renamed or reused, so a typo
    // here is a product id abandoned forever. That is what this test is guarding.
    @Test
    func productIdsAreExact() {
        #expect(Tip.tiny.rawValue == "com.aptumtek.app.Paperless.tip.tiny")
        #expect(Tip.small.rawValue == "com.aptumtek.app.Paperless.tip.small")
        #expect(Tip.medium.rawValue == "com.aptumtek.app.Paperless.tip.medium")
        #expect(Tip.large.rawValue == "com.aptumtek.app.Paperless.tip.large")
    }

    // Not the rendered order - price decides that. This is the tie-break two equally priced tips
    // fall back on, and the record of which rank each case is meant to be.
    @Test
    func casesAreDeclaredSmallestFirst() {
        #expect(Tip.allCases == [.tiny, .small, .medium, .large])
    }
}
