import XCTest
@testable import Networking

final class EndpointTests: XCTestCase {
    func test_endpoint_defaultsToGet() {
        let endpoint = Endpoint(path: "members/1")
        XCTAssertEqual(endpoint.method, .get)
        XCTAssertTrue(endpoint.queryItems.isEmpty)
    }

    func test_networkError_equatable() {
        XCTAssertEqual(NetworkError.server(statusCode: 500), .server(statusCode: 500))
        XCTAssertNotEqual(NetworkError.server(statusCode: 500), .server(statusCode: 503))
    }
}
