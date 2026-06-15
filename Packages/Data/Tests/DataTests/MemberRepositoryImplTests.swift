import XCTest
import Domain
import Networking
@testable import Data

private struct StubHTTPClient: HTTPClient {
    let result: Result<Data, NetworkError>
    func data(for endpoint: Endpoint) async throws -> Data {
        try result.get()
    }
}

final class MemberRepositoryImplTests: XCTestCase {
    func test_member_decodesAndMapsToDomainEntity() async throws {
        let json = Data(#"{"id":"1","name":"민호","email":"mino@team.com"}"#.utf8)
        let sut = MemberRepositoryImpl(client: StubHTTPClient(result: .success(json)))

        let member = try await sut.member(id: MemberID("1"))

        XCTAssertEqual(member.id, MemberID("1"))
        XCTAssertEqual(member.name, "민호")
        XCTAssertEqual(member.email, "mino@team.com")
    }

    func test_member_translatesNotFoundToMemberNotFound() async {
        let sut = MemberRepositoryImpl(client: StubHTTPClient(result: .failure(.notFound)))

        do {
            _ = try await sut.member(id: MemberID("404"))
            XCTFail("에러가 발생해야 한다")
        } catch let error as DomainError {
            XCTAssertEqual(error, .memberNotFound)
        } catch {
            XCTFail("DomainError 로 변환되어야 한다: \(error)")
        }
    }
}
