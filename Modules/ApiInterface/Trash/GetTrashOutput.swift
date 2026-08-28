import Foundation
import Tagged

/// The trash lists whole documents, not references to them - `/api/documents/{id}/` answers 404 once
/// a document is in here, so this response is the only place its title, tags and correspondent can
/// be read.
public typealias GetTrashOutput = ListOutput<Document, Document.Id>
