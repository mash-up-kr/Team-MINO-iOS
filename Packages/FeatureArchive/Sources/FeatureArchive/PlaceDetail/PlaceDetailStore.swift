import Domain
import Foundation
import MVI

struct PlaceDetailState: Equatable {
    var place: PlaceDetailPlace
    var comments: [PlaceDetailComment] = []
    /// 출처(인스타그램 게시물) 링크. 목록 응답에는 실리지 않아 진입 후 핀 단독 조회로 채운다.
    /// 끝까지 nil 이면 열 곳이 없다는 뜻이라 "원문보기" 를 비활성으로 둔다.
    var sourceURL: URL?
    var isLoadingSource = false
}

enum PlaceDetailAction: Equatable {
    case load
    case sourceLoaded(URL?)
    case sourceLoadFailed(DomainError)
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
    useCase: FetchPinDetailUseCase,
    pin: Pin,
    makeCommentID: @escaping () -> String = { UUID().uuidString }
) -> (inout PlaceDetailState, PlaceDetailAction) -> Effect<PlaceDetailAction, PlaceDetailNav> {
    { state, action in
        switch action {
        case .load:
            guard !state.isLoadingSource else { return .none }
            state.isLoadingSource = true
            return .run { send in
                do {
                    send(.sourceLoaded(try await useCase.execute(pinID: pin.id).sourceURL))
                } catch is CancellationError {
                    return                                   // 화면을 떠난 것 — 실패가 아니다
                } catch let error as DomainError {
                    send(.sourceLoadFailed(error))
                } catch {
                    send(.sourceLoadFailed(.unknown))
                }
            }

        case .sourceLoaded(let url):
            state.sourceURL = url
            state.isLoadingSource = false
            return .none

        case .sourceLoadFailed:
            // 출처는 화면의 곁가지라 오류 UI 를 띄우지 않는다 — 버튼이 비활성으로 남는 것으로 족하다.
            state.isLoadingSource = false
            return .none

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
