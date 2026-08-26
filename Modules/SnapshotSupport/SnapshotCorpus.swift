#if DEBUG
import ApiInterface
import Foundation

// Which documents each language's screenshots show, and in which order.
//
// The two lists are deliberately different documents rather than the same ones relabelled: the
// German screenshots show German paperwork - utility bills, a tax office, a bank statement - which
// is what a German user's archive actually looks like. Both are drawn from the same seeded
// instance, so neither is invented.
extension SnapshotConfiguration.Corpus {

    // The order shown, because the stub returns these as they are. The first is the document the
    // view and edit screenshots open, so it leads: the capture taps the first row rather than
    // naming a document, which would mean knowing each language's corpus.
    //
    // Both leading documents have a real PDF in docker/data. The utility bills are generated
    // filler pages and would photograph as a blank sheet.
    var documentIds: [Document.Id] {
        switch self {
        case .english:
            [8, 13, 12, 5, 4, 2, 1, 6, 3]
        case .german:
            [6, 21, 22, 23, 16, 14, 17, 20]
        }
    }

    // The subset carrying the Inbox tag. Kept explicit rather than derived, because the inbox
    // screenshot wants a short, readable list rather than everything that happens to be tagged.
    var inboxDocumentIds: [Document.Id] {
        switch self {
        case .english:
            [12, 5, 4]
        case .german:
            [14, 15, 20]
        }
    }
}
#endif
