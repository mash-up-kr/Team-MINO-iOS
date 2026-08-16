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

/// 코멘트는 아직 서버 모델이 없어 화면 상태로만 쌓인다 — 엔티티가 생기면 UseCase 주입으로 교체한다.
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
