import Domain
import Foundation
import MVI

struct PlaceDetailState: Equatable {
    var place: PlaceDetailPlace
    var comments: [PlaceDetailComment] = []
}

enum PlaceDetailAction: Equatable {
    case submitComment(String)
    case tapClose
    case tapShare
}

enum PlaceDetailNav: Equatable, Sendable {
    case close
    case share(RoomDetailLocation)
}

typealias PlaceDetailStore = Store<PlaceDetailState, PlaceDetailAction, PlaceDetailNav>

func placeDetailReducer(
    pin: Pin,
    makeCommentID: @escaping () -> String = { UUID().uuidString }
) -> (inout PlaceDetailState, PlaceDetailAction) -> Effect<PlaceDetailAction, PlaceDetailNav> {
    { state, action in
        switch action {
        case .submitComment(let text):
            let body = String(
                text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(PlaceDetailComment.bodyLimit)
            )
            guard !body.isEmpty else { return .none }
            state.comments.append(
                PlaceDetailComment(
                    id: makeCommentID(),
                    author: PlaceDetailComment.localAuthorName,
                    body: body
                )
            )
            return .none

        case .tapClose:
            return .navigate(.close)

        case .tapShare:
            return .navigate(.share(RoomDetailLocation(from: pin)))
        }
    }
}
