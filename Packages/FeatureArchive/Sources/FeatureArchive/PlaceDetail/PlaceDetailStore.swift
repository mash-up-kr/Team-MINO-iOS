import Domain
import Foundation
import MVI

struct PlaceDetailState: Equatable {
    var place: PlaceDetailPlace
    var comments: [Comment] = []
}

/// 내가 작성한 코멘트의 표시 이름 — 로컬 표시 규칙이라 Feature 가 정한다.
let placeDetailLocalAuthorName = "나"

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
    makeCommentID: @escaping () -> CommentID = { CommentID(UUID().uuidString) }
) -> (inout PlaceDetailState, PlaceDetailAction) -> Effect<PlaceDetailAction, PlaceDetailNav> {
    { state, action in
        switch action {
        case .submitComment(let text):
            guard let body = CommentBody(text) else { return .none }
            state.comments.append(
                Comment(id: makeCommentID(), author: placeDetailLocalAuthorName, body: body)
            )
            return .none

        case .tapClose:
            return .navigate(.close)

        case .tapShare:
            return .navigate(.share(RoomDetailLocation(from: pin)))
        }
    }
}
