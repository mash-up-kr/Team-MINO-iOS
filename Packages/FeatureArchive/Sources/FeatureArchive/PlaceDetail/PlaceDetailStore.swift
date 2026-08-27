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
    /// 지금 이 앱을 쓰는 사람. 코멘트 소유 판정의 유일한 기준값이라 **못 가져오면 nil 로 남긴다** —
    /// 그러면 어떤 코멘트도 내 것으로 보지 않아 남의 글에 삭제가 붙는 사고가 나지 않는다.
    var currentMember: MemberProfile?
    var isLoadingCurrentMember = false
}

extension PlaceDetailState {
    /// 코멘트를 등록할 수 있는가. 작성자를 신원으로 싣기 때문에 내가 누구인지 모르면 쓸 수 없다.
    var canSubmitComment: Bool { currentMember != nil }
}

enum PlaceDetailAction: Equatable {
    case load
    case sourceLoaded(URL?)
    case sourceLoadFailed(DomainError)
    case loadCurrentMember
    case currentMemberLoaded(MemberProfile)
    case currentMemberLoadFailed(DomainError)
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
    fetchCurrentMember: CurrentMemberUseCase,
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

        // 출처 조회와 한 effect 로 묶지 않는다 — 둘은 실패해도 서로 막을 이유가 없고,
        // 하나로 합치면 한쪽 실패가 다른 쪽 결과까지 끌고 내려간다.
        case .loadCurrentMember:
            guard state.currentMember == nil, !state.isLoadingCurrentMember else { return .none }
            state.isLoadingCurrentMember = true
            return .run { send in
                do {
                    send(.currentMemberLoaded(try await fetchCurrentMember.execute()))
                } catch is CancellationError {
                    return
                } catch let error as DomainError {
                    send(.currentMemberLoadFailed(error))
                } catch {
                    send(.currentMemberLoadFailed(.unknown))
                }
            }

        case .currentMemberLoaded(let profile):
            state.currentMember = profile
            state.isLoadingCurrentMember = false
            return .none

        case .currentMemberLoadFailed:
            // 신원을 모르는 채로 두는 게 정답이다 — 오류 UI 없이 삭제 케밥이 안 붙고 등록이 잠긴다.
            state.isLoadingCurrentMember = false
            return .none

        case .submitComment(let text):
            // 작성자를 신원으로 싣기 때문에 내가 누구인지 모르면 만들 수 없다. 등록 버튼도 같은
            // 조건으로 잠겨 있어 정상 흐름에서는 여기 도달하지 않는다.
            guard let author = state.currentMember else { return .none }
            let body = String(
                text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(PlaceDetailComment.bodyLimit)
            )
            guard !body.isEmpty else { return .none }
            state.comments.append(
                PlaceDetailComment(id: makeCommentID(), author: author, body: body)
            )
            return .none

        case .tapClose:
            return .navigate(.close)

        case .tapShare:
            return .navigate(.share(RoomDetailLocation(from: pin)))
        }
    }
}
