import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import SwiftSharing
import Tagged

@Reducer
public struct DocumentRowReducer: Sendable {
    public enum Action: ViewAction {
        case destination(PresentationAction<Destination.Action>)
        case delegate(Delegate)
        case view(View)

        public enum Delegate {
            case presentDocumentDetail(Shared<Document>)
        }

        public enum View {
            case editButtonTapped
            case rowTapped
        }
    }

    @Reducer
    public enum Destination {
        case documentForm(DocumentFormReducer)
    }

    @ObservableState
    public struct State: Equatable, Identifiable {

        public var id: Document.Id { document.id }

        var correspondent: String {
            document.correspondent?.get(server)?.name ?? "-"
        }

        @Presents
        var destination: Destination.State?

        @Shared
        var document: Document

        var documentType: String? {
            document.documentType?.get(server)?.name
        }

        var storagePath: String? {
            document.storagePath?.get(server)?.name
        }

        let server: Server

        var tags: [Tag] {
            document.tags.compactMap { $0.get(server) }
        }

        var titleLineLimit: Int {
            var titleLineLimit = 6
            if document.archiveSerialNumber != nil {
                titleLineLimit -= 1
            }
            if document.documentType != nil {
                titleLineLimit -= 1
            }
            if document.storagePath != nil {
                titleLineLimit -= 1
            }
            return titleLineLimit
        }

        init(
            document: Shared<Document>,
            server: Server
        ) {
            self._document = document
            self.server = server
        }
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .destination(.presented(.documentForm(.delegate(.documentUpdated)))):
                state.destination = nil
                return .none
            case let .view(viewAction):
                switch viewAction {
                case .editButtonTapped:
                    state.destination = .documentForm(DocumentFormReducer.State(
                        document: state.$document,
                        server: state.server
                    ))
                    return .none
                case .rowTapped:
                    return .send(.delegate(.presentDocumentDetail(state.$document)))
                }
            case .delegate, .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}

extension DocumentRowReducer.Action.Delegate: Equatable {}
extension DocumentRowReducer.Destination.State: Equatable {}
