import Foundation
import Domain

/// 백엔드 미연결 단계용 `PinCommentRepository` 구현.
///
/// 코멘트 API 가 없어 **메모리에 들고 있는다.** 그냥 성공만 돌려주면 등록·삭제가 화면 상태에만
/// 남아 시트를 닫았다 다시 열면 쓴 코멘트가 사라진다(이슈 #165).
///
/// 디스크까지 영속시키지 않는 이유: 형제 목이 전부 프로세스 수명이다(``MockPinRepository`` 의
/// 삭제, 「다른 방에 공유」의 저장). 코멘트만 재실행 뒤에도 살아남으면 "지운 장소는
/// 되살아나는데 코멘트는 남아 있는" 앞뒤 안 맞는 목업이 된다. 게다가 목 핀 id 에는 `page`·
/// `filter` 가 섞여 있어(``MockPinRepository``) 재실행 뒤 같은 장소가 같은 핀이라는 보장도 없다.
///
/// 네트워크처럼 잠깐 기다렸다 성공하는 지연은 등록·삭제 버튼이 잠기는 걸 실물처럼 보기 위한
/// 것이다. 조회에는 지연을 두지 않는다 — 형제 목의 읽기 경로와 같고, 목록이 늦게 오면
/// "아직 코멘트가 없어요" 가 잠깐 스친다.
///
/// 추후 네트워크 `PinCommentRepositoryImpl`(DTO → `toDomain()` 매핑) 로 교체하면 이 파일만
/// 지운다. 지금은 직렬화하는 곳이 없어 DTO 도 두지 않는다 — 쓰이지 않는 Codable 타입을 미리
/// 깔아 두면 실 스키마가 오는 날 어차피 다시 쓴다.
public final class MockPinCommentRepository: PinCommentRepository {
    private let pins: PinDetailRepository
    private let currentMember: CurrentMemberRepository
    private let store = PinCommentStore()

    /// - Parameter pins: 이 장소에 코멘트가 **몇 개 달려 있다고 카드가 말했는지**(``Pin/commentCount``)를
    ///   알아내는 데 쓴다. 그 수만큼 친구 코멘트를 깔아 두지 않으면 목록 카드는 "코멘트 7" 인데
    ///   상세는 "아직 코멘트가 없어요" 가 되어 목업이 스스로와 어긋난다.
    /// - Parameter currentMember: 등록한 코멘트의 작성자. 실 서버는 토큰에서 뽑으므로 인터페이스
    ///   (``PinCommentRepository/post(pinID:body:)``)가 작성자를 받지 않는다 — 목도 같은 자리에서 구한다.
    public init(pins: PinDetailRepository, currentMember: CurrentMemberRepository) {
        self.pins = pins
        self.currentMember = currentMember
    }

    public func comments(pinID: PinID) async throws -> [PinComment] {
        await loaded(pinID)
    }

    public func post(pinID: PinID, body: String) async throws -> PinComment {
        // 목록을 읽기 전에 등록부터 하면(진입 직후 빠른 입력) 씨앗이 깔릴 자리를 잃어
        // 친구 코멘트가 통째로 사라진다 — 먼저 깔고 붙인다.
        _ = await loaded(pinID)
        try? await Task.sleep(for: .milliseconds(300))
        let author = try await currentMember.currentMember()
        let comment = PinComment(
            id: PinCommentID("comment-\(UUID().uuidString)"),
            pinID: pinID,
            author: author,
            body: body,
            createdAt: .now
        )
        await store.append(comment)
        return comment
    }

    /// 지울 수 있는 사람인지는 서버가 판정할 몫이라 목은 id 만 보고 지운다.
    /// 화면이 이미 소유를 두 겹으로 막고 있어(케밥 표시 + 리듀서 가드) 남의 줄이 여기 닿지 않는다.
    public func delete(pinID: PinID, commentID: PinCommentID) async throws {
        try? await Task.sleep(for: .milliseconds(300))
        await store.remove(commentID, from: pinID)
    }

    // MARK: - Mock 합성

    /// 이 핀의 코멘트를 처음 만지는 순간 친구 코멘트를 깔고, 그 뒤로는 보관소 것을 그대로 쓴다.
    private func loaded(_ pinID: PinID) async -> [PinComment] {
        if let known = await store.comments(for: pinID) { return known }
        let seed = makeSeed(pinID: pinID, count: await commentCount(of: pinID))
        return await store.seed(seed, for: pinID)
    }

    private func commentCount(of pinID: PinID) async -> Int {
        // 목록을 거치지 않고 들어온 핀(목이 합성한 적 없는 id)은 조회가 실패한다 — 그때는
        // 깔 씨앗이 없다고 보고 빈 목록에서 시작한다.
        (try? await pins.pinDetail(id: pinID).pin.commentCount) ?? 0
    }

    /// 같은 핀이면 같은 코멘트가 나오도록 id 로 결정한다 — 다시 열 때마다 남의 코멘트가
    /// 바뀌면 "내가 아까 본 그 장소" 라는 감각이 깨진다.
    private func makeSeed(pinID: PinID, count: Int) -> [PinComment] {
        let now = Date.now
        return (0..<count).map { index in
            PinComment(
                id: PinCommentID("comment-\(pinID.value)-\(index)"),
                pinID: pinID,
                author: Self.friends[index % Self.friends.count],
                body: Self.bodies[index % Self.bodies.count],
                createdAt: now.addingTimeInterval(Double(index - count) * 3_600)
            )
        }
    }

    /// 씨앗 작성자에 "나"(user-0001)를 넣지 않는다 — 넣으면 쓴 적 없는 코멘트에 삭제 케밥이
    /// 붙는다. ``MockRoomRepository`` 의 방 멤버와 같은 사람들이라 아바타·닉네임이 어긋나지 않는다.
    private static let friends: [MemberProfile] = [
        MemberProfile(id: MemberID("user-0002"), nickname: "지훈", avatarColor: .redOrange),
        MemberProfile(id: MemberID("user-0003"), nickname: "서연", avatarColor: .orange),
        MemberProfile(id: MemberID("user-0004"), nickname: "민준", avatarColor: .green),
    ]

    private static let bodies: [String] = [
        "웨이팅 있어서 오픈런했는데 그럴 만했어요",
        "주차가 애매해서 근처 공영주차장 쓰는 게 나아요",
        "창가 자리 뷰가 진짜 좋아요. 해질 때 가보세요",
        "평일 낮엔 한산해서 얘기하기 좋았어요",
        "디저트가 생각보다 달아요. 아메리카노랑 같이!",
        "화장실이 건물 밖에 있어요 참고하세요",
        "사장님이 친절하셔서 또 가고 싶어요",
    ]
}

/// 어떤 핀에 어떤 코멘트가 달렸는지. 목이 프로세스 수명 동안만 기억한다.
private actor PinCommentStore {
    private var byPin: [String: [PinComment]] = [:]

    func comments(for pinID: PinID) -> [PinComment]? { byPin[pinID.value] }

    /// 먼저 깐 쪽이 이긴다 — 조회와 등록이 겹쳐 들어와도 씨앗이 두 번 깔리지 않는다.
    func seed(_ comments: [PinComment], for pinID: PinID) -> [PinComment] {
        if let existing = byPin[pinID.value] { return existing }
        byPin[pinID.value] = comments
        return comments
    }

    func append(_ comment: PinComment) {
        byPin[comment.pinID.value, default: []].append(comment)
    }

    /// 핀을 함께 받으므로 그 칸만 훑는다 — 전체 순회하던 시절의 "id 가 겹치면 남의 핀 줄도
    /// 사라진다" 는 여지가 없어진다.
    func remove(_ commentID: PinCommentID, from pinID: PinID) {
        byPin[pinID.value]?.removeAll { $0.id == commentID }
    }
}
