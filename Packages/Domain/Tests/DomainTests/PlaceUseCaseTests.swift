import XCTest
@testable import Domain

private final class StubPinDetailRepository: PinDetailRepository {
    let result: Result<PinDetail, DomainError>
    init(result: Result<PinDetail, DomainError>) { self.result = result }
    func pinDetail(id: PinID) async throws -> PinDetail { try result.get() }
}

private final class StubCurrentMemberRepository: CurrentMemberRepository {
    let result: Result<MemberProfile, DomainError>
    init(result: Result<MemberProfile, DomainError>) { self.result = result }
    func currentMember() async throws -> MemberProfile { try result.get() }
}

private actor StubSavePinRepository: SavePinRepository {
    let targets: [ShareTarget]
    private(set) var savedPinID: PinID?
    private(set) var savedRoomIDs: Set<String>?

    init(targets: [ShareTarget] = []) { self.targets = targets }

    func save(pinID: PinID, toRoomIDs roomIDs: Set<String>) async throws {
        savedPinID = pinID
        savedRoomIDs = roomIDs
    }

    func shareTargets(pinID: PinID) async throws -> [ShareTarget] { targets }
}

final class PlaceUseCaseTests: XCTestCase {
    func test_fetchPinDetail_returnsDetailFromRepository() async throws {
        let expected = PinDetail(pin: PinFixture.pin(), sourceURL: URL(string: "https://instagram.com/p/abc"))
        let sut = DefaultFetchPinDetailUseCase(repository: StubPinDetailRepository(result: .success(expected)))

        let detail = try await sut.execute(pinID: PinID("pin-1"))

        XCTAssertEqual(detail, expected)
    }

    func test_fetchPinDetail_propagatesDomainError() async {
        let sut = DefaultFetchPinDetailUseCase(repository: StubPinDetailRepository(result: .failure(.unknown)))

        do {
            _ = try await sut.execute(pinID: PinID("404"))
            XCTFail("에러가 전파되어야 한다")
        } catch let error as DomainError {
            XCTAssertEqual(error, .unknown)
        } catch {
            XCTFail("DomainError 가 아닌 오류: \(error)")
        }
    }

    func test_currentMember_returnsProfileFromRepository() async throws {
        let expected = MemberProfile(id: MemberID("me"), nickname: "지훈", avatarID: 3)
        let sut = DefaultCurrentMemberUseCase(repository: StubCurrentMemberRepository(result: .success(expected)))

        let member = try await sut.execute()

        XCTAssertEqual(member, expected)
    }

    func test_fetchShareTargets_keepsAlreadySavedFlagPerRoom() async throws {
        let targets = [
            ShareTarget(room: PinFixture.room(id: "room-1"), alreadySaved: true),
            ShareTarget(room: PinFixture.room(id: "room-2"), alreadySaved: false),
        ]
        let sut = DefaultFetchShareTargetsUseCase(repository: StubSavePinRepository(targets: targets))

        let result = try await sut.execute(pinID: PinID("pin-1"))

        XCTAssertEqual(result, targets)
    }

    func test_savePinToRooms_doesNotCallRepositoryWhenNoRoomSelected() async throws {
        let repository = StubSavePinRepository()
        let sut = DefaultSavePinToRoomsUseCase(repository: repository)

        try await sut.execute(pinID: PinID("pin-1"), roomIDs: [])

        let saved = await repository.savedPinID
        XCTAssertNil(saved, "고른 방이 없으면 저장 요청을 보내지 않는다")
    }
}
