import Foundation

/// HTTP 통신 추상. 구현체는 URLSession 등 인프라에 의존한다.
public protocol HTTPClient: Sendable {
    func data(for endpoint: Endpoint) async throws -> Data
}
