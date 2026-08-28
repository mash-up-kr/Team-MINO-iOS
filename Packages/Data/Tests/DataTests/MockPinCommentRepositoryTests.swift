import Foundation
import Testing
import Domain
@testable import Data

/// 목이 "쓴 코멘트를 기억한다"는 것과 "카드가 말한 개수만큼 친구 코멘트를 깐다"는 것을 본다.
/// 그냥 성공만 돌려주는 목이면 시트를 닫았다 다시 열 때마다 쓴 코멘트가 사라지는데(#165),
/// 화면 리듀서 테스트로는 그 회귀가 잡히지 않는다.
@Suite("MockPinCommentRepository 지속")
struct MockPinCommentRepositoryTests {
    private static let me = MemberProfile(id: MemberID("user-0001"), nickname: "나", avatarID: 1)
    private static let pinID = PinID("pin-1")

    /// 코멘트 개수만 정해 주는 핀 상세 스텁 — 목이 씨앗을 몇 개 깔지는 이 값으로 정해진다.
    private struct StubPinDetail: PinDetailRepository {
        let commentCount: Int
        /// 목록을 거치지 않고 들어온 핀처럼 조회 자체를 실패시킨다.
        var fails = false

        func pinDetail(id: PinID) async throws -> PinDetail {
            if fails { throw DomainError.unknown }
            return PinDetail(
                pin: Pin(
                    id: id,
                    roomID: "room-1",
                    place: Place(
                        id: PlaceID("place-1"),
                        name: "레이어스튜디오 10",
                        address: "서울 성동구 상원4길 10",
                        coordinate: Coordinate(latitude: 37.5443, longitude: 127.0557),
                        category: "카페"
                    ),
                    commentCount: commentCount,
                    category: .worthVisiting,
                    createdAt: Date(timeIntervalSince1970: 0)
                ),
                sourceURL: nil
            )
        }
    }

    private struct StubCurrentMember: CurrentMemberRepository {
        func currentMember() async throws -> MemberProfile { me }
    }

    private func makeSUT(commentCount: Int = 3, pinDetailFails: Bool = false) -> MockPinCommentRepository {
        MockPinCommentRepository(
            pins: StubPinDetail(commentCount: commentCount, fails: pinDetailFails),
            currentMember: StubCurrentMember()
        )
    }

    // MARK: - 씨앗

    @Test("카드가 말한 코멘트 수만큼 친구 코멘트를 깔아 둔다")
    func seedsAsManyAsCommentCount() async throws {
        let sut = makeSUT(commentCount: 5)

        #expect(try await sut.comments(pinID: Self.pinID).count == 5)
    }

    @Test("씨앗에는 '나' 가 없다 — 쓴 적 없는 코멘트에 삭제 케밥이 붙으면 안 된다")
    func seedIsNeverAuthoredByMe() async throws {
        let sut = makeSUT(commentCount: 7)

        let seeded = try await sut.comments(pinID: Self.pinID)

        #expect(!seeded.contains { $0.isWritten(by: Self.me.id) })
    }

    @Test("같은 핀을 다시 조회해도 같은 코멘트가 온다")
    func seedIsStableAcrossReads() async throws {
        let sut = makeSUT(commentCount: 3)

        let first = try await sut.comments(pinID: Self.pinID)
        let second = try await sut.comments(pinID: Self.pinID)

        #expect(first == second)
    }

    @Test("코멘트가 0인 장소는 비어 있다")
    func seedsNothingWhenCountIsZero() async throws {
        let sut = makeSUT(commentCount: 0)

        #expect(try await sut.comments(pinID: Self.pinID).isEmpty)
    }

    @Test("핀 상세를 못 읽으면 씨앗 없이 시작한다 — 조회가 실패로 끝나지는 않는다")
    func startsEmptyWhenPinLookupFails() async throws {
        let sut = makeSUT(commentCount: 5, pinDetailFails: true)

        #expect(try await sut.comments(pinID: Self.pinID).isEmpty)
    }

    // MARK: - 등록

    @Test("등록한 코멘트는 다시 조회해도 남아 있다 — #165 의 본체")
    func postedCommentSurvivesRefetch() async throws {
        let sut = makeSUT(commentCount: 0)

        let posted = try await sut.post(pinID: Self.pinID, body: "좋았어요")
        let after = try await sut.comments(pinID: Self.pinID)

        #expect(after == [posted])
    }

    @Test("등록한 코멘트의 작성자는 지금 앱을 쓰는 사람이라 바로 지울 수 있다")
    func postedCommentIsMine() async throws {
        let sut = makeSUT(commentCount: 0)

        let posted = try await sut.post(pinID: Self.pinID, body: "좋았어요")

        #expect(posted.isWritten(by: Self.me.id))
        #expect(posted.pinID == Self.pinID)
        #expect(posted.body == "좋았어요")
    }

    @Test("목록을 읽기 전에 등록해도 친구 코멘트가 사라지지 않는다")
    func postBeforeFirstReadKeepsSeed() async throws {
        let sut = makeSUT(commentCount: 3)

        let posted = try await sut.post(pinID: Self.pinID, body: "좋았어요")
        let after = try await sut.comments(pinID: Self.pinID)

        #expect(after.count == 4)
        #expect(after.last == posted)
    }

    @Test("코멘트는 장소마다 따로 쌓인다")
    func commentsAreScopedToPin() async throws {
        let sut = makeSUT(commentCount: 0)

        _ = try await sut.post(pinID: Self.pinID, body: "여기 좋아요")

        #expect(try await sut.comments(pinID: PinID("pin-2")).isEmpty)
    }

    // MARK: - 삭제

    @Test("지운 코멘트는 다시 조회해도 오지 않는다")
    func deletedCommentStaysGone() async throws {
        let sut = makeSUT(commentCount: 0)
        let posted = try await sut.post(pinID: Self.pinID, body: "좋았어요")

        try await sut.delete(commentID: posted.id)

        #expect(try await sut.comments(pinID: Self.pinID).isEmpty)
    }

    @Test("지우지 않은 코멘트는 그대로 남는다")
    func deleteKeepsOthers() async throws {
        let sut = makeSUT(commentCount: 2)
        let posted = try await sut.post(pinID: Self.pinID, body: "좋았어요")
        let before = try await sut.comments(pinID: Self.pinID)

        try await sut.delete(commentID: posted.id)
        let after = try await sut.comments(pinID: Self.pinID)

        #expect(after == Array(before.dropLast()))
    }
}
