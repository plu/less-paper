@testable import TipsFeature

import Foundation
import Testing

@Suite
struct TipProductSortingTests {

    // StoreKit promises no order at all, so the input here is deliberately scrambled rather than
    // reversed: a sort that only handled reversal would pass a reversed fixture.
    @Test
    func sortedByPrice_ordersAscendingWhateverTheInputOrder() {
        let sorted = [
            TipProduct(displayName: "Medium tip", displayPrice: "€10.00", price: 10, tip: .medium),
            TipProduct(displayName: "Tiny tip", displayPrice: "€1.00", price: 1, tip: .tiny),
            TipProduct(displayName: "Large tip", displayPrice: "€25.00", price: 25, tip: .large),
            TipProduct(displayName: "Small tip", displayPrice: "€5.00", price: 5, tip: .small),
        ]
        .sortedByPrice()

        #expect(sorted.map(\.tip) == [.tiny, .small, .medium, .large])
    }

    // Swift's sorted(by:) is not stable, so two tips at the same price could otherwise swap between
    // calls - a list that reshuffles while the user looks at it. Two rungs priced alike is not a
    // state worth supporting, but it happens transiently while a price change propagates, and
    // "sometimes reorders itself" is a far worse symptom than "shows a fixed order".
    @Test
    func sortedByPrice_breaksTiesOnDeclarationOrder() {
        let products = [
            TipProduct(displayName: "Large tip", displayPrice: "€5.00", price: 5, tip: .large),
            TipProduct(displayName: "Small tip", displayPrice: "€5.00", price: 5, tip: .small),
            TipProduct(displayName: "Tiny tip", displayPrice: "€5.00", price: 5, tip: .tiny),
        ]

        #expect(products.sortedByPrice().map(\.tip) == [.tiny, .small, .large])
    }

    // The tie-break must be deterministic, not merely correct once.
    @Test
    func sortedByPrice_isStableAcrossRepeatedCalls() {
        let products = [
            TipProduct(displayName: "Large tip", displayPrice: "€5.00", price: 5, tip: .large),
            TipProduct(displayName: "Small tip", displayPrice: "€5.00", price: 5, tip: .small),
            TipProduct(displayName: "Tiny tip", displayPrice: "€5.00", price: 5, tip: .tiny),
        ]

        let first = products.sortedByPrice().map(\.tip)
        for _ in 0 ..< 20 {
            #expect(products.sortedByPrice().map(\.tip) == first)
        }
    }

    // Prices are Decimal rather than Double because they are money: 0.1 + 0.2 must not be a factor
    // in what order a user's options appear in.
    @Test
    func sortedByPrice_comparesFractionalPricesExactly() {
        let sorted = [
            TipProduct(displayName: "b", displayPrice: "€1.30", price: Decimal(string: "1.30")!, tip: .small),
            TipProduct(displayName: "a", displayPrice: "€1.10", price: Decimal(string: "1.10")!, tip: .tiny),
        ]
        .sortedByPrice()

        #expect(sorted.map(\.displayName) == ["a", "b"])
    }

    @Test
    func sortedByPrice_returnsEmptyForEmpty() {
        #expect([TipProduct]().sortedByPrice().isEmpty)
    }
}
