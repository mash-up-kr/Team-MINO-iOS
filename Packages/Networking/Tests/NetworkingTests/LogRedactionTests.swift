import Foundation
import Testing
@testable import Networking

/// 릴리즈 동작을 **DEBUG 빌드에서** 검증한다. `#if DEBUG` 안에 마스킹을 두면
/// 테스트가 컴파일 아웃돼서, 정작 지켜야 할 쪽이 검증되지 않는다.
@Suite("로그 마스킹")
struct LogRedactionTests {
    // 초대 코드 하나면 누구나 그 방에 입장할 수 있다. 이게 이 파일이 존재하는 이유다.
    @Test("초대 코드는 경로에 있으므로 쿼리만 떼는 것으로는 안 가려진다")
    func masksInviteCode() {
        let masked = LogRedaction.maskIdentifiers(in: "/api/v1/invitations/FOOD1234")

        #expect(masked == "/api/v1/invitations/***")
        #expect(!masked.contains("FOOD1234"))
    }

    @Test("UUID·숫자 식별자도 가린다", arguments: [
        ("/api/v1/rooms/3fa85f64-5717-4562-b3fc-2c963f66afa6", "/api/v1/rooms/***"),
        ("/api/v1/pins/12345/comments", "/api/v1/pins/***/comments"),
        ("/api/v1/rooms/3fa85f64-5717-4562-b3fc-2c963f66afa6/members/me",
         "/api/v1/rooms/***/members/me"),
    ])
    func masksIdentifiers(_ input: String, _ expected: String) {
        #expect(LogRedaction.maskIdentifiers(in: input) == expected)
    }

    // 전부 가리면 어느 API 가 실패했는지 알 수 없어 로그가 쓸모없어진다.
    @Test("고정 세그먼트는 남긴다 — 어느 API 인지는 알아야 한다")
    func keepsRouteShape() {
        #expect(LogRedaction.maskIdentifiers(in: "/api/v1/rooms") == "/api/v1/rooms")
        #expect(LogRedaction.maskIdentifiers(in: "/api/v1/users/me") == "/api/v1/users/me")
    }

    @Test("릴리즈 URL 은 호스트·쿼리를 떼고 마스킹된 경로만 남긴다")
    func releaseURL() {
        let url = URL(string: "https://api.gguk.org/api/v1/invitations/FOOD1234?token=secret")!

        #expect(LogRedaction.url(url, full: false) == "/api/v1/invitations/***")
        #expect(LogRedaction.url(url, full: true).contains("token=secret"))
    }

    // 서버 에러 본문에는 요청 에코·닉네임·방 이름이 실릴 수 있다.
    @Test("릴리즈 본문 로그는 내용 대신 크기만 남긴다")
    func releaseBody() {
        let body = Data(#"{"errorCode":"FORBIDDEN","message":"김유빈님은 멤버가 아닙니다"}"#.utf8)

        let release = LogRedaction.body(body, includePreview: false)
        #expect(release["preview"] == nil)
        #expect(release["bodyBytes"] == String(body.count))

        let debug = LogRedaction.body(body, includePreview: true)
        #expect(debug["preview"]?.contains("FORBIDDEN") == true)
    }
}
