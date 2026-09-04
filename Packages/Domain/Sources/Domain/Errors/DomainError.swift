import Foundation

/// 비즈니스 어휘로만 표현되는 도메인 오류.
/// 인프라(NetworkError 등) 오류는 Data 계층에서 이 타입으로 변환된다.
public enum DomainError: Error, Equatable, Sendable {
    case memberNotFound
    case roomsFetchFailed
    /// 방을 만들거나 고치지 못했다.
    case roomSaveFailed
    case notificationsFetchFailed
    /// 공유받은 링크를 방에 담지 못함. 방 저장(`roomSaveFailed`)과 갈라 둔다 —
    /// 익스텐션은 이 실패만 스낵바로 보여주고 방 편집 화면은 이 오류를 받지 않는다.
    case linkSaveFailed
    case unauthorized
    /// 세션은 있지만 이 uid 로 **회원 등록이 되어 있지 않다**(서버 `USER_NOT_REGISTERED`).
    ///
    /// `unauthorized` 와 반드시 구분한다 — 이쪽은 인증이 깨진 게 아니라 **온보딩을 아직 안 마친**
    /// 상태다. 앱 진입 분기가 이 값 하나로 온보딩과 재시도를 가른다.
    case notRegistered
    /// 이미 등록된 uid 로 다시 등록을 시도했다(서버 `USER_ALREADY_REGISTERED`).
    ///
    /// 익명 세션은 Keychain 에 남아 앱을 지웠다 깔아도 같은 uid 로 돌아온다 —
    /// 재설치한 사용자가 온보딩을 다시 타면 여기에 닿는다.
    case alreadyRegistered
    /// 세션을 확보하지 못했다. 인증 수단에 닿지 못한 경우로,
    /// **서버가 거부한 `unauthorized` 와 구분한다** — 이쪽은 재시도가 의미 있다.
    case sessionUnavailable
    /// 기기가 네트워크에 닿지 못했다(연결 없음·호스트 못 찾음·응답 시간 초과).
    ///
    /// **서버까지 갔다가 실패한 경우와 구분한다** — 스플래시가 이 값 하나로 "네트워크 연결을
    /// 확인해주세요"와 "일시적인 오류가 발생했어요"를 가른다. 아직 이 둘을 갈라 보여주는 화면이
    /// 스플래시뿐이라 번역도 그 경로(`ProfileRepositoryImpl`·`FirebaseAuthRepository`)에만 있다.
    case networkUnavailable
    /// 프로필을 읽지 못했다(조회 실패). 재시도가 의미 있다.
    case profileFetchFailed
    /// 프로필을 저장하지 못했다 — 등록·수정 공통.
    case profileSaveFailed
    /// 초대 코드를 얻지 못했다. 재시도가 의미 있다.
    case inviteCodeFetchFailed
    /// 초대가 없거나 이미 만료됐다(서버 `INVITATION_NOT_FOUND`).
    ///
    /// 초대 진입은 이 값 하나로 "초대를 없던 것으로 치고 평소 진입" 을 결정한다 —
    /// 재시도해도 결과가 같으므로 `inviteCodeFetchFailed` 와 갈라 둔다.
    case invitationNotFound
    /// 개인방에는 합류할 수 없다(서버 `PERSONAL_ROOM_NOT_ALLOWED`).
    ///
    /// 만료(`invitationNotFound`)와 나누는 건 사용자에게 보여줄 문구가 달라서다 —
    /// 링크가 낡은 것과 애초에 들어갈 수 없는 방인 것은 다른 안내가 필요하다.
    case personalRoomNotAllowed
    /// 빈 코멘트를 등록하려 했다 — 공백만 친 경우를 포함한다.
    ///
    /// 등록 버튼이 이미 잠기지만(화면), 유스케이스도 스스로 막는다. 뷰를 고치면 뚫리는 방어라
    /// 도메인 경계에서 한 번 더 세우고, 그 거절을 오류로 드러낸다.
    case commentBodyEmpty
    /// 코멘트 목록을 읽지 못했다. 재시도가 의미 있다.
    ///
    /// 셋(`commentsFetchFailed`·`commentPostFailed`·`commentDeleteFailed`)을 갈라 둔다.
    /// 지금 장소 상세는 셋을 같은 결로 처리하지만, 세 실패가 `unknown` 한 값으로 수렴하면
    /// **번역되지 않은 오류**(`NetworkError.logUntranslated()` 가 잡아내려는 것)와 구분이
    /// 사라진다 — 리소스별 폴백 어휘를 두는 건 형제 Repository 전부가 지키는 규약이다
    /// (`pinsFetchFailed`·`roomsFetchFailed`·`pinShareFailed`).
    case commentsFetchFailed
    /// 코멘트를 남기지 못했다. 빈 본문 거절(`commentBodyEmpty`)과 갈라 둔다 —
    /// 그쪽은 보내기 전에 유스케이스가 막은 것이고, 이쪽은 서버까지 갔다가 실패한 것이다.
    case commentPostFailed
    /// 코멘트를 지우지 못했다. 서버가 작성자가 아니라고 판정한 경우(403)도 여기로 흡수한다 —
    /// 화면이 그 거절을 따로 보여 줄 자리가 아직 없다.
    case commentDeleteFailed
    /// 저장한 장소를 읽지 못했다 — 홈 카드 덱·방 상세 목록·장소 상세 공통. 재시도가 의미 있다.
    case pinsFetchFailed
    /// 이미 저장한 장소를 **다른 방에 담지 못했다**(011-1).
    ///
    /// 링크 저장(`linkSaveFailed`)과 갈라 둔다 — 그쪽은 익스텐션이 인스타 링크를 처음 담는 경로라
    /// 실패 스낵바가 따로 있고, 이쪽은 앱 안에서 이미 있는 장소를 복제하는 다른 화면이다.
    case pinShareFailed
    case unknown
}
