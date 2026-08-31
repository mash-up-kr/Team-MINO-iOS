import Foundation

/// 이 장소가 **중복 저장된 방**들을 가져온다 (기획 014 ②).
///
/// 장소가 원래 속한 방은 결과에서 뺀다 — 014 는 "이 장소를 지금 보고 있는 방 말고 또 어디에
/// 담아 뒀나" 를 보여주는 화면이라, 보고 있는 방이 목록에 있으면 답이 되지 않는다
/// (기획 014 ② "장소가 방 A에 속해있는 상태라면, 방 A는 표출되지 않는다").
///
/// 결과가 비어 있으면 중복 저장이 아니다 — 진입 버튼(기획 005-1 ⑮ "중복 저장된 장소 클릭 시에만
/// 활성화된다")의 활성 조건이 곧 이 목록의 유무다.
public protocol FetchSavedRoomsUseCase: Sendable {
    /// - Parameter pin: 조회할 장소. id 가 아니라 **핀째** 받는 이유는 빼야 할 방(``Pin/roomID``)이
    ///   핀에 실려 있기 때문이다 — 핀 id 와 제외할 방 id 를 따로 받으면 서로 맞지 않는 짝을
    ///   넘길 수 있고, 그러면 엉뚱한 방이 목록에서 빠진다.
    func execute(pin: Pin) async throws -> [Room]
}

public struct DefaultFetchSavedRoomsUseCase: FetchSavedRoomsUseCase {
    private let repository: ShareTargetRepository

    public init(repository: ShareTargetRepository) {
        self.repository = repository
    }

    /// 공유 후보 조회(``ShareTargetRepository/shareTargets(placeID:)``)를 그대로 재사용한다 —
    /// "방 목록 + 그 방에 이 장소가 있는지" 가 이미 한 조회로 오므로 저장된 방만 따로 물을
    /// API 가 필요 없다. 고르는 규칙(이미 저장됨 ∧ 원래 방 아님)만 여기서 정한다.
    public func execute(pin: Pin) async throws -> [Room] {
        try await repository.shareTargets(placeID: pin.place.id)
            .filter { $0.alreadySaved && $0.room.id != pin.roomID }
            .map(\.room)
    }
}
