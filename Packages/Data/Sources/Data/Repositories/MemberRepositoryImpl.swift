import Foundation
import Domain
import Networking

public final class MemberRepositoryImpl: MemberRepository {
    private let client: HTTPClient

    public init(client: HTTPClient) {
        self.client = client
    }

    public func member(id: MemberID) async throws -> Member {
        let endpoint = Endpoint(path: "members/\(id.value)")
        do {
            let data = try await client.data(for: endpoint)
            let dto = try JSONDecoder().decode(MemberDTO.self, from: data)
            return dto.toDomain()
        } catch let error as NetworkError {
            throw Self.mapToDomain(error)
        } catch is DecodingError {
            throw DomainError.unknown
        }
    }

    /// 반부패 계층(Anti-Corruption): 인프라 오류를 도메인 오류로 번역한다.
    private static func mapToDomain(_ error: NetworkError) -> DomainError {
        switch error {
        case .notFound:
            return .memberNotFound
        case .unauthorized:
            return .unauthorized
        case .invalidURL, .server, .decodingFailed, .transport:
            return .unknown
        }
    }
}
