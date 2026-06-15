import Foundation

/// 네트워크 인프라 계층의 오류. 이 타입은 Networking 내부에 격리되며
/// Domain 으로 새어 나가면 안 된다. (Data 계층에서 DomainError 로 변환)
public enum NetworkError: Error, Equatable, Sendable {
    case invalidURL
    case unauthorized
    case notFound
    case server(statusCode: Int)
    case decodingFailed
    case transport
}
