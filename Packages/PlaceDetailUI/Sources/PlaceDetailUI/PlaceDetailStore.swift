import Domain
import Foundation
import MVI

public struct PlaceDetailState: Equatable {
    var place: PlaceDetailPlace
    /// 이 장소에 달린 코멘트. 화면이 지어내는 값이 아니라 **저장소에서 받아 온 것**이라
    /// 화면을 나갔다 들어와도 같은 목록이 온다(#165).
    var comments: [PinComment] = []
    var isLoadingComments = false
    /// 조회가 한 번이라도 끝났는가. "아직 안 물어봤다" 와 "물어봤더니 없더라" 를 가른다 —
    /// 이걸 안 가르면 진입 첫 프레임(조회 시작 전)에 "아직 코멘트가 없어요" 가 스쳤다가
    /// 목록으로 바뀐다.
    var hasLoadedComments = false
    /// 등록 요청을 보내고 응답을 기다리는 중 — 등록 버튼이 이 값으로 잠긴다.
    var isSubmittingComment = false
    /// 출처(인스타그램 게시물) 링크. 목록 응답에는 실리지 않아 진입 후 핀 단독 조회로 채운다.
    /// 끝까지 nil 이면 열 곳이 없다는 뜻이라 "원문보기" 를 비활성으로 둔다.
    var sourceURL: URL?
    var isLoadingSource = false
    /// 지금 이 앱을 쓰는 사람. 코멘트 소유 판정의 유일한 기준값이라 **못 가져오면 nil 로 남긴다** —
    /// 그러면 어떤 코멘트도 내 것으로 보지 않아 남의 글에 삭제가 붙는 사고가 나지 않는다.
    var currentMember: MemberProfile?
    var isLoadingCurrentMember = false
    /// 이 장소가 **중복 저장된 방**들(기획 014 ②). 지금 보고 있는 방은 빠져 있다.
    ///
    /// 목록을 화면이 들고 있는 이유는 이게 곧 '저장된 방' 버튼의 활성 조건이기 때문이다 —
    /// 버튼을 켜 놓고 시트에서 다시 받아오면 켠 근거와 그리는 목록이 갈라질 수 있다.
    var savedRooms: [Room] = []
    var isLoadingSavedRooms = false
    /// 삭제 메뉴가 열려 있는 코멘트. 목록 전체에서 하나만 열린다.
    ///
    /// 방 상세의 케밥 메뉴는 열림 상태를 View 가 들지만(모든 카드에 케밥이 있어 UI 사정일 뿐),
    /// 이쪽은 **열 수 있는지 자체가 소유 판정**이라 reduce 가 쥔다.
    var menuCommentID: PinCommentID?
    /// ⑭ 코멘트 삭제 확인 다이얼로그. nil 이면 닫혀 있다.
    var commentDeletion: PlaceDetailCommentDeletion?
    /// 현위치 버튼이 내 위치를 기다리는 중. 연타로 위치 요청(과 시스템 팝업)을 겹쳐 내보내지 않는다.
    ///
    /// 좌표는 담지 않는다 — 이 화면이 쓸 일이 없고(카메라는 지도가 든다), 들고 있으면 두 번째
    /// 탭이 낡은 좌표로 돌아가 버린다. 누를 때마다 새로 묻는 게 "현위치" 의 뜻에 맞다.
    var isLocating = false
}

extension PlaceDetailState {
    /// 이 코멘트에 삭제 케밥을 붙일 수 있는가. 뷰가 그릴지 말지를 이 값 하나로 정한다.
    func canDelete(_ comment: PinComment) -> Bool {
        comment.isWritten(by: currentMember?.id)
    }

    /// 코멘트를 등록할 수 있는가. 작성자를 신원으로 싣기 때문에 내가 누구인지 모르면 쓸 수 없고,
    /// 보낸 요청이 아직 안 돌아왔으면 같은 글이 두 번 올라가지 않게 잠근다.
    var canSubmitComment: Bool { currentMember != nil && !isSubmittingComment }

    /// "아직 코멘트가 없어요" 를 띄울 때인가. 물어보기 전·물어보는 중에는 띄우지 않는다.
    var showsCommentEmptyState: Bool { comments.isEmpty && hasLoadedComments }

    /// '저장된 방' 버튼(005-1 ⑮)을 누를 수 있는가 — "중복 저장된 장소 클릭 시에만 활성화된다".
    /// 목록이 비면 이 장소는 지금 보는 방에만 있다는 뜻이라 보여 줄 방이 없다.
    ///
    /// 이 버튼은 시트 **밖**(지도 위)에 있어 화면을 띄운 쪽이 그린다 — 그래서 공개한다.
    public var canOpenSavedRooms: Bool { !savedRooms.isEmpty }
}

public enum PlaceDetailAction: Equatable {
    case load
    case sourceLoaded(URL?)
    case sourceLoadFailed(DomainError)
    case loadComments
    case commentsLoaded([PinComment])
    case commentsLoadFailed(DomainError)
    case loadCurrentMember
    case currentMemberLoaded(MemberProfile)
    case currentMemberLoadFailed(DomainError)
    case loadSavedRooms
    case savedRoomsLoaded([Room])
    case savedRoomsLoadFailed(DomainError)
    case tapSavedRooms
    case tapMyLocation
    case myLocationResolved(CurrentLocationResult)
    case submitComment(String)
    case commentPosted(PinComment)
    case commentPostFailed(DomainError)
    case tapCommentMenu(PinCommentID)
    case dismissCommentMenu
    case tapDeleteComment(PinCommentID)
    case cancelDeleteComment
    case confirmDeleteComment
    case commentDeleted(PinCommentID)
    case commentDeleteFailed(DomainError)
    case tapClose
    case tapShare
}

public enum PlaceDetailNav: Equatable, Sendable {
    case close
    /// 다른 방에 공유. 표시 모델이 아니라 도메인 핀을 싣는다 — 공유 시트를 어떤 모양으로
    /// 그릴지는 이 화면을 띄운 쪽(Feature)이 정한다.
    case share(Pin)
    /// 저장된 방 시트(014)로. 목록을 함께 실어 보낸다 — 시트가 다시 받아오면 버튼을 켠 목록과
    /// 갈라진다.
    case openSavedRooms(SavedRoomsPresentation)
    /// 지도를 내 위치로 옮긴다(005-1 현위치 버튼).
    ///
    /// 지도는 이 시트가 아니라 껍데기(``ArchiveShellView``)의 것이라 reduce 가 직접 손댈 수 없다.
    /// 화면 밖으로 나가는 지시는 전부 Nav 로 흘려 Coordinator 가 받는다 — push/present 와 같은 길이다.
    case focusMyLocation(Coordinate)
}

public typealias PlaceDetailStore = Store<PlaceDetailState, PlaceDetailAction, PlaceDetailNav>

func placeDetailReducer(
    useCase: FetchPinDetailUseCase,
    fetchCurrentMember: CurrentMemberUseCase,
    fetchSavedRooms: FetchSavedRoomsUseCase,
    fetchComments: FetchPinCommentsUseCase,
    postComment: PostPinCommentUseCase,
    deleteComment: DeletePinCommentUseCase,
    /// 005-1 현위치 버튼이 쓰는 내 위치. 그 버튼은 지도 위에 있으므로 지도를 가진 진입점만 그린다.
    currentLocation: CurrentLocationUseCase,
    pin: Pin
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

        // 코멘트도 출처·신원·저장된 방과 따로 받는다 — 넷 다 서로를 막을 이유가 없다.
        case .loadComments:
            guard !state.isLoadingComments else { return .none }
            state.isLoadingComments = true
            return .run { send in
                do {
                    send(.commentsLoaded(try await fetchComments.execute(pinID: pin.id)))
                } catch is CancellationError {
                    return
                } catch let error as DomainError {
                    send(.commentsLoadFailed(error))
                } catch {
                    send(.commentsLoadFailed(.unknown))
                }
            }

        case .commentsLoaded(let comments):
            state.comments = comments
            state.isLoadingComments = false
            state.hasLoadedComments = true
            return .none

        case .commentsLoadFailed:
            // 이미 그려 둔 목록은 손대지 않는다 — 못 받은 것과 없는 것은 다르고, 있던 줄을
            // 지우면 실패가 "코멘트가 사라졌다" 로 보인다.
            //
            // `hasLoadedComments` 도 켜지 않는다: 실패는 "없더라" 가 아니라 "모르겠다" 라서
            // 빈 상태를 띄우면 거짓말이 된다. 시안 005-1 에 조회 실패 화면이 없어 지금은 자리가
            // 비어 있고, 실 API 가 붙으면 여기에 재시도 UI 를 붙인다.
            state.isLoadingComments = false
            return .none

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

        case .loadSavedRooms:
            guard !state.isLoadingSavedRooms else { return .none }
            state.isLoadingSavedRooms = true
            return .run { send in
                do {
                    send(.savedRoomsLoaded(try await fetchSavedRooms.execute(pin: pin)))
                } catch is CancellationError {
                    return
                } catch let error as DomainError {
                    send(.savedRoomsLoadFailed(error))
                } catch {
                    send(.savedRoomsLoadFailed(.unknown))
                }
            }

        case .savedRoomsLoaded(let rooms):
            state.savedRooms = rooms
            state.isLoadingSavedRooms = false
            return .none

        case .savedRoomsLoadFailed:
            // 출처 조회와 같은 결 — 곁가지라 오류 UI 를 띄우지 않고 버튼이 비활성으로 남는다.
            // 목록을 비워 두는 쪽으로 실패한다: 못 받은 목록으로 시트를 여는 것보다 안 열리는 게 낫다.
            state.savedRooms = []
            state.isLoadingSavedRooms = false
            return .none

        case .tapSavedRooms:
            // 뷰가 비활성으로 막지만 뷰를 고치면 뚫린다 — 빈 시트가 뜨지 않게 여기서도 지킨다.
            guard state.canOpenSavedRooms else { return .none }
            return .navigate(
                .openSavedRooms(SavedRoomsPresentation(id: pin.id.value, rooms: state.savedRooms))
            )

        case .tapMyLocation:
            // 연타로 위치 요청(과 시스템 팝업)을 두 번 내보내지 않는다 — 거리순 정렬(004-1 ⑥)의
            // `roomDetailReducer` 가 `isLocating` 으로 하는 것과 같은 가드다.
            guard !state.isLocating else { return .none }
            state.isLocating = true
            return .run { send in
                let result = await currentLocation.execute()
                // 화면을 떠나 취소된 것 — 실패가 아니라 결과가 필요 없어진 것이다.
                // (유스케이스가 throw 하지 않아 `catch is CancellationError` 대신 여기서 거른다)
                guard !Task.isCancelled else { return }
                send(.myLocationResolved(result))
            }

        case .myLocationResolved(let result):
            state.isLocating = false
            guard case .coordinate(let coordinate) = result else {
                // 좌표를 못 얻었다(권한 거부 · 측위 실패). **아무것도 하지 않는다** — 지도가
                // 그대로인 것이 곧 "못 옮겼다" 는 표시다.
                //
                // 시안 005-1 에는 이 실패를 알리는 화면(토스트·안내·설정 앱 유도)이 없다. 없는
                // UI 를 지어내지 않는 쪽으로 거리순 정렬(004-1 ⑥, `roomDetailReducer` 의
                // `.locationResolved`)이 이미 판단했고 그 결과와 일관성을 지킨다.
                // `CurrentLocationResult` 가 사유(`permissionDenied` / `unavailable`)를 구분해
                // 오므로, 안내 화면이 정해지면 여기서 갈라 쓰면 된다.
                return .none
            }
            return .navigate(.focusMyLocation(coordinate))

        // 낙관적 갱신(먼저 붙이고 실패하면 되돌리기)을 쓰지 않는다. 이유 셋:
        //  · 코멘트 id 는 삭제·메뉴의 손잡이인데, 낙관적으로 붙이려면 임시 id 를 만들어 응답이 온 뒤
        //    서버 id 로 바꿔치기해야 한다. 그 사이에 케밥을 열면 사라진 id 를 가리킨다
        //  · 시안 005-1 에 등록 실패를 알리는 UI(토스트·스낵바)가 없다. 붙였다 되돌리면 사용자에겐
        //    아무 설명 없이 글이 사라지는 것으로만 보인다
        //  · 같은 화면 계열의 장소 삭제(``roomDetailReducer`` 의 `.confirmDelete`)가 이미 응답 후
        //    갱신이다. 바로 옆 흐름과 실패 거동이 갈리면 무엇이 반영된 것인지 읽을 수 없다
        case .submitComment(let text):
            // 작성자를 신원으로 싣기 때문에 내가 누구인지 모르면 만들 수 없다. 등록 버튼도 같은
            // 조건으로 잠겨 있어 정상 흐름에서는 여기 도달하지 않는다.
            guard state.canSubmitComment else { return .none }
            // 빈 글로 요청을 내보내지 않기 위한 앞단 검사다. 공백 제거·200자 절단의 **최종 판정은
            // 유스케이스**(``DefaultPostPinCommentUseCase``)에 있다 — 상한은 서버가 거절하는
            // 길이라 화면이 아니라 도메인의 규칙이다.
            let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else { return .none }
            state.isSubmittingComment = true
            return .run { send in
                do {
                    send(.commentPosted(try await postComment.execute(pinID: pin.id, body: body)))
                } catch is CancellationError {
                    return
                } catch let error as DomainError {
                    send(.commentPostFailed(error))
                } catch {
                    send(.commentPostFailed(.unknown))
                }
            }

        case .commentPosted(let comment):
            state.isSubmittingComment = false
            // 같은 등록이 두 번 들어와도 줄이 겹쳐 늘지 않는다.
            guard !state.comments.contains(where: { $0.id == comment.id }) else { return .none }
            state.comments.append(comment)
            return .none

        case .commentPostFailed:
            // 실패 피드백(토스트)은 시안 005-1 에 없다. 목록에 아무것도 안 붙는 것이 곧
            // "안 올라갔다" 는 표시다.
            //
            // 이때 입력창은 이미 비어 있어(뷰가 보낸 직후 지운다) 친 글이 사라진다. 목은 실패하지
            // 않아 지금은 닿지 않는 경로지만, 실 API 가 붙어 실패가 실제로 일어나면 draft 를
            // State 로 올려 되돌려 줘야 한다.
            state.isSubmittingComment = false
            return .none

        case .tapCommentMenu(let id):
            // 남의 코멘트엔 케밥이 없지만, 소유 판정을 뷰에만 맡기지 않는다.
            let viewer = state.currentMember?.id
            guard state.comments.contains(where: { $0.id == id && $0.isWritten(by: viewer) })
            else { return .none }
            state.menuCommentID = id
            return .none

        case .dismissCommentMenu:
            state.menuCommentID = nil
            return .none

        // ⑭ "클릭 시 삭제하기 모달이 활성화된다" — 메뉴를 누른 것만으로는 지우지 않는다.
        case .tapDeleteComment(let id):
            state.menuCommentID = nil
            // 남의 코멘트엔 케밥이 없지만, 뷰를 고치면 뚫린다 — 다이얼로그를 여는 자리에서도 소유를 본다.
            let viewer = state.currentMember?.id
            guard state.comments.contains(where: { $0.id == id && $0.isWritten(by: viewer) })
            else { return .none }
            state.commentDeletion = PlaceDetailCommentDeletion(commentID: id)
            return .none

        case .cancelDeleteComment:
            state.commentDeletion = nil
            return .none

        case .confirmDeleteComment:
            // 이미 보낸 요청이 있으면 무시한다 — 확인 버튼은 잠기지만 접근성 조작 등으로 두 번 들어올 수 있다.
            guard let deletion = state.commentDeletion, !deletion.isSubmitting else { return .none }
            // 소유는 여기서 한 번 더 본다 — 서버가 최종 판정하지만, 남의 줄로 요청이 나가는 것부터 막는다.
            let owner = state.currentMember?.id
            guard state.comments.contains(where: {
                $0.id == deletion.commentID && $0.isWritten(by: owner)
            }) else { return .none }

            state.commentDeletion?.isSubmitting = true
            return .run { send in
                do {
                    try await deleteComment.execute(pinID: pin.id, commentID: deletion.commentID)
                    send(.commentDeleted(deletion.commentID))
                } catch is CancellationError {
                    return
                } catch let error as DomainError {
                    send(.commentDeleteFailed(error))
                } catch {
                    send(.commentDeleteFailed(.unknown))
                }
            }

        case .commentDeleted(let id):
            state.commentDeletion = nil
            state.comments.removeAll { $0.id == id }
            return .none

        case .commentDeleteFailed:
            // 장소 삭제(``roomDetailReducer`` 의 `.deleteFailed`)와 같은 결 — 실패 UI 가 시안에
            // 없다. 다이얼로그만 닫고 목록은 손대지 않는다: 지우려던 줄이 그 자리에 남아 있는 것이
            // 곧 "안 지워졌다" 는 표시다.
            state.commentDeletion = nil
            return .none

        case .tapClose:
            return .navigate(.close)

        case .tapShare:
            return .navigate(.share(pin))
        }
    }
}
