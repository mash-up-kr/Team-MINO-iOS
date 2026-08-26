import Foundation
import Domain

/// 백엔드 미연결 단계용 `ProfileRepository` 구현.
/// 네트워크 대신 하드코딩 JSON(Swagger `GET /api/v1/users/me` 응답 형태)을 디코드해 반환한다.
/// DTO → `toDomain()` 경계 매핑을 실제로 태우므로, 추후 네트워크 `ProfileRepositoryImpl` 로
/// 교체해도 매핑 계층은 그대로 재사용된다.
///
/// 저장한 값은 프로세스가 살아 있는 동안만 유지된다 — 등록/수정 결과를 곧바로 조회로 확인할 수 있게
/// 최소한만 흉내 낸다.
public actor MockProfileRepository: ProfileRepository {
    private var stored: Profile?

    public init() {}

    public func register(nickname: String, avatarIndex: Int) async throws -> Profile {
        try? await Task.sleep(nanoseconds: 300_000_000)   // 로딩 상태 시범용 지연
        let profile = try Self.decode(nickname: nickname, avatarIndex: avatarIndex)
        stored = profile
        return profile
    }

    public func me() async throws -> Profile {
        try? await Task.sleep(nanoseconds: 300_000_000)
        if let stored { return stored }
        return try Self.decode(nickname: "꾹이", avatarIndex: 0)
    }

    public func update(nickname: String?, avatarIndex: Int?) async throws -> Profile {
        try? await Task.sleep(nanoseconds: 300_000_000)
        let base = try stored ?? Self.decode(nickname: "꾹이", avatarIndex: 0)
        let profile = Profile(
            id: base.id,
            nickname: nickname ?? base.nickname,
            avatarIndex: avatarIndex ?? base.avatarIndex,
            createdAt: base.createdAt
        )
        stored = profile
        return profile
    }

    /// 실제 응답 형태를 그대로 태워 매핑을 검증한다 — 값만 바꿔 끼운다.
    private static func decode(nickname: String, avatarIndex: Int) throws -> Profile {
        let json = """
        {
          "data": {
            "id": "00000000-0000-0000-0000-000000000001",
            "nickname": "\(nickname)",
            "avatar": { "id": \(avatarIndex) },
            "createdAt": "2026-01-01T00:00:00.000Z"
          }
        }
        """
        do {
            return try JSONDecoder().decode(ProfileResponseDTO.self, from: Data(json.utf8)).data.toDomain()
        } catch {
            throw DomainError.profileSaveFailed
        }
    }
}
