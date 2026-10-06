@testable import ImageFeature

import ApiInterface
import Dependencies
import Nuke
import Testing
import TestSupport

@Suite(
    .testDependencies {
        $0.apiSessionDelegate = ApiSessionDelegate()
    }
)
struct PipelineProviderTests {

    @Test
    func liveValue_buildsPipelineLoadingThroughImageLoader() {
        let pipeline = PipelineProvider.liveValue.build(.testValue())

        #expect(pipeline.configuration.dataLoader is ImageLoader)
    }

    @Test
    func testValue_buildsPipelineWithATestImage() {
        let pipeline = PipelineProvider.testValue.build(.testValue())

        #expect(pipeline.configuration.dataLoader is TestImageLoader)
    }

    @Test
    func previewValue_buildsPipelineWithATestImage() {
        let pipeline = PipelineProvider.previewValue.build(.testValue())

        #expect(pipeline.configuration.dataLoader is TestImageLoader)
    }

    @Test
    func loadingValue_buildsPipelineThatNeverAnswers() {
        let pipeline = PipelineProvider.loadingValue.build(.testValue())

        #expect(pipeline.configuration.dataLoader is TestImageLoader)
    }

    @Test
    func failingValue_buildsPipelineThatAlwaysFails() {
        let pipeline = PipelineProvider.failingValue.build(.testValue())

        #expect(pipeline.configuration.dataLoader is TestImageLoader)
    }
}
