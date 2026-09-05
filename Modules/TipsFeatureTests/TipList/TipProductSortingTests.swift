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

    // Not repetition - sorted(by:) is deterministic within a process, so calling it twice proves
    // nothing. What a missing tie-break actually changes is sensitivity to input order, so this
    // feeds the same equally priced products in every order and expects one answer.
    @Test
    func sortedByPrice_ordersEqualPricesIndependentlyOfInputOrder() {
        let tiny = TipProduct(displayName: "Tiny tip", displayPrice: "€5.00", price: 5, tip: .tiny)
        let small = TipProduct(displayName: "Small tip", displayPrice: "€5.00", price: 5, tip: .small)
        let large = TipProduct(displayName: "Large tip", displayPrice: "€5.00", price: 5, tip: .large)

        let permutations: [[TipProduct]] = [
            [tiny, small, large],
            [tiny, large, small],
            [small, tiny, large],
            [small, large, tiny],
            [large, tiny, small],
            [large, small, tiny],
        ]

        for input in permutations {
            #expect(input.sortedByPrice().map(\.tip) == [.tiny, .small, .large])
        }
    }

    // Prices are Decimal rather than Double because they are money. 0.1 + 0.2 is exactly 0.3 in
    // Decimal and 0.30000000000000004 in Double, so these two are equal here and the tie-break
    // decides - putting tiny first. Retype `price` to Double and this test fails, which is the
    // whole point of it.
    @Test
    func sortedByPrice_comparesPricesExactlyRatherThanApproximately() {
        let summed = Decimal(string: "0.1")! + Decimal(string: "0.2")!
        let exact = Decimal(string: "0.3")!

        #expect(summed == exact)

        let sorted = [
            TipProduct(displayName: "Tiny tip", displayPrice: "€0.30", price: summed, tip: .tiny),
            TipProduct(displayName: "Small tip", displayPrice: "€0.30", price: exact, tip: .small),
        ]
        .sortedByPrice()

        #expect(sorted.map(\.tip) == [.tiny, .small])
    }

    @Test
    func sortedByPrice_returnsEmptyForEmpty() {
        #expect([TipProduct]().sortedByPrice().isEmpty)
    }
}
