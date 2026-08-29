import Domain

/// 장소 상세 화면이 요구하는 좁은 의존성 묶음.
///
/// 이 화면을 띄우는 flow(저장 탭·홈)의 deps 프로토콜이 이것을 확장한다 — 그러면 조립부(App)는
/// 지금처럼 자기 flow 의 deps 하나만 준수하면 되고, 화면은 자기가 쓰는 여섯 개만 본다.
public protocol PlaceDetailDeps {
    /// "원문보기" 가 쓰는 핀 단독 조회 — 목록 응답에는 출처 링크가 실리지 않는다.
    var fetchPinDetail: FetchPinDetailUseCase { get }
    /// 지금 앱을 쓰는 사람 — "이 코멘트가 내 것인가"(삭제 케밥을 붙일지)를 이걸로 가른다.
    var currentMember: CurrentMemberUseCase { get }
    /// 이 장소가 중복 저장된 방들 — '저장된 방' 버튼(005-1 ⑮)의 활성 조건이자 014 시트의 목록이다.
    var fetchSavedRooms: FetchSavedRoomsUseCase { get }
    /// "친구들의 코멘트" 목록 — 화면 상태가 아니라 저장소에서 받아 온다(#165).
    var fetchComments: FetchPinCommentsUseCase { get }
    /// 코멘트 등록. 작성자·식별자는 서버가 정하므로 결과를 받아 목록에 붙인다.
    var postComment: PostPinCommentUseCase { get }
    /// 코멘트 삭제(005-1 ⑭) — 확인 다이얼로그를 거친 뒤 지운다.
    var deleteComment: DeletePinCommentUseCase { get }
}

/// 장소 상세 Store 를 만든다. 이 화면의 **유일한 진입점**이다.
///
/// `handle:` 을 받는 init 을 쓰므로 navigation 구독이 생성에 묶여 있다 — 맨손
/// `Store(_:reduce:)` + `observeNavigation` 은 구독을 빠뜨리면 화면 전환이 크래시·로그 없이
/// 조용히 안 된다(`mvi-coordinator-di.md` §4).
///
/// 리듀서를 직접 노출하지 않는 이유는 인자가 일곱 개라, 진입점마다 손으로 엮으면 한 곳에서만
/// 유스케이스를 빠뜨려도 그 화면의 코멘트·저장된 방이 조용히 비기 때문이다.
@MainActor
public func makePlaceDetailStore(
    pin: Pin,
    deps: PlaceDetailDeps,
    handle: @escaping @MainActor (PlaceDetailNav) -> Void
) -> PlaceDetailStore {
    PlaceDetailStore(
        PlaceDetailState(place: PlaceDetailPlace(from: pin)),
        reduce: placeDetailReducer(
            useCase: deps.fetchPinDetail,
            fetchCurrentMember: deps.currentMember,
            fetchSavedRooms: deps.fetchSavedRooms,
            fetchComments: deps.fetchComments,
            postComment: deps.postComment,
            deleteComment: deps.deleteComment,
            pin: pin
        ),
        handle: handle
    )
}
