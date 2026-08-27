import Foundation
import Domain

/// 백엔드 미연결 단계용 `CurrentMemberRepository` 구현.
///
/// `MockRoomRepository` 의 방 멤버 `user-0001`("나") 과 **같은 사람**이어야 한다.
/// 어긋나면 내가 방장인 방에서 방 편집이 안 뜨고, 내가 쓴 코멘트에 삭제 아이콘이 안 붙는다.
///
/// 추후 프로필 API 가 붙으면 이 파일만 지운다.
public final class MockCurrentMemberRepository: CurrentMemberRepository {
    public init() {}

    public func currentMember() async throws -> MemberProfile {
        MemberProfile(id: MemberID("user-0001"), nickname: "나", avatarID: 1)
    }
}
