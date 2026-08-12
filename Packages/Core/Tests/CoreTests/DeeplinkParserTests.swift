import Foundation
import Testing
@testable import Core

private let configuration = DeeplinkConfiguration(scheme: "gguk", host: "gguk.app")
private let parser = DeeplinkParser(configuration: configuration)

struct DeeplinkParserTests {
    @Test("Universal Link 초대 링크를 목적지로 읽는다")
    func parsesWebInviteLink() {
        #expect(parser.parse(URL(string: "https://gguk.app/invite/AB12")!) == .invite(code: "AB12"))
    }

    @Test("custom scheme 초대 링크를 같은 목적지로 읽는다 — host 가 첫 세그먼트다")
    func parsesAppSchemeInviteLink() {
        #expect(parser.parse(URL(string: "gguk://invite/AB12")!) == .invite(code: "AB12"))
    }

    @Test("스킴·호스트 대소문자는 무시한다", arguments: [
        "HTTPS://GGUK.APP/invite/AB12",
        "GGUK://INVITE/AB12"
    ])
    func ignoresSchemeAndHostCase(_ raw: String) {
        #expect(parser.parse(URL(string: raw)!) == .invite(code: "AB12"))
    }

    @Test("우리 것이 아닌 URL 은 버린다", arguments: [
        "https://evil.app/invite/AB12",     // 남의 호스트
        "http://gguk.app/invite/AB12",      // https 가 아님
        "other://invite/AB12"              // 남의 스킴
    ])
    func rejectsForeignURL(_ raw: String) {
        #expect(parser.parse(URL(string: raw)!) == nil)
    }

    @Test("모르는 경로나 불완전한 코드는 버린다", arguments: [
        "https://gguk.app/unknown/AB12",    // 모르는 목적지
        "https://gguk.app/invite",          // 코드 없음
        "https://gguk.app/invite/",         // 빈 코드
        "https://gguk.app/invite/AB12/x",   // 세그먼트 초과
        "https://gguk.app",                 // 경로 없음
        "gguk://invite"                    // 코드 없음
    ])
    func rejectsMalformedPath(_ raw: String) {
        #expect(parser.parse(URL(string: raw)!) == nil)
    }
}
