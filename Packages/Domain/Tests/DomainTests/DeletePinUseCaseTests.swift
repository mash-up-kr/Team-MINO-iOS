import Testing
@testable import Domain

private actor StubPinDeletionRepository: PinDeletionRepository {
    private let error: DomainError?
    private(set) var deletedPinIDs: [PinID] = []

    init(error: DomainError? = nil) { self.error = error }

    func delete(pinID: PinID) async throws {
        deletedPinIDs.append(pinID)
        if let error { throw error }
    }
}

struct DeletePinUseCaseTests {
    @Test("고른 장소의 id 를 그대로 저장소에 넘긴다")
    func passesPinIDToRepository() async throws {
        let repository = StubPinDeletionRepository()
        let sut = DefaultDeletePinUseCase(repository: repository)

        try await sut.execute(pinID: PinID("pin-7"))

        #expect(await repository.deletedPinIDs == [PinID("pin-7")])
    }

    @Test("저장소 오류를 그대로 올려보낸다 — 삼켜 버리면 화면이 지워진 줄 안다")
    func propagatesRepositoryError() async {
        let sut = DefaultDeletePinUseCase(repository: StubPinDeletionRepository(error: .unknown))

        await #expect(throws: DomainError.unknown) {
            try await sut.execute(pinID: PinID("pin-7"))
        }
    }
}
