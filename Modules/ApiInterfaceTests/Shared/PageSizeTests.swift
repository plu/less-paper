@testable import ApiInterface

import Foundation
import Testing

@Suite
struct PageSizeTests {

    @Test
    func valueFromValidString() async throws {
        #expect(PageSize.value(from: "10") == 10)
    }

    @Test
    func valueFromNil() async throws {
        #expect(PageSize.value(from: nil) == PageSize.default)
    }

    @Test
    func valueFromNonNumericString() async throws {
        #expect(PageSize.value(from: "not a number") == PageSize.default)
    }

    @Test
    func valueFromZero() async throws {
        #expect(PageSize.value(from: "0") == PageSize.default)
    }

    @Test
    func valueFromNegativeNumber() async throws {
        #expect(PageSize.value(from: "-5") == PageSize.default)
    }

    @Test
    func defaultIsOneHundred() async throws {
        #expect(PageSize.default == 100)
    }
}
