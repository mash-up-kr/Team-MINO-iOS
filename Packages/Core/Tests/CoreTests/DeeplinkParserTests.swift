import Foundation
import Testing
@testable import Core

private let configuration = DeeplinkConfiguration(scheme: "gguk", host: "gguk.org")
private let parser = DeeplinkParser(configuration: configuration)

struct DeeplinkParserTests {
    @Test("Universal Link 초대 링크를 목적지로 읽는다")
    func parsesWebInviteLink() {
        #expect(parser.parse(URL(string: "https://gguk.org/r/AB12")!) == .invite(code: "AB12"))
    }

    @Test("custom scheme 초대 링크를 같은 목적지로 읽는다 — host 가 첫 세그먼트다")
    func parsesAppSchemeInviteLink() {
        #expect(parser.parse(URL(string: "gguk://r/AB12")!) == .invite(code: "AB12"))
    }

    @Test("스킴·호스트·목적지 이름의 대소문자는 무시한다 — 두 진입 경로가 같은 규칙을 쓴다", arguments: [
        "HTTPS://GGUK.ORG/r/AB12",
        "https://GGUK.ORG/R/AB12",
        "GGUK://R/AB12"
    ])
    func ignoresSchemeHostAndRouteCase(_ raw: String) {
        #expect(parser.parse(URL(string: raw)!) == .invite(code: "AB12"))
    }

    @Test("초대 코드의 대소문자는 보존한다 — 서버가 구분하는지 모르므로 뭉개지 않는다")
    func preservesCodeCase() {
        #expect(parser.parse(URL(string: "gguk://r/aB12")!) == .invite(code: "aB12"))
    }

    @Test("설정의 스킴·호스트는 대소문자를 정규화해 받는다")
    func normalizesConfiguration() {
        let parser = DeeplinkParser(configuration: DeeplinkConfiguration(scheme: "GGUK", host: "GGUK.APP"))

        #expect(parser.parse(URL(string: "gguk://r/AB12")!) == .invite(code: "AB12"))
    }

    @Test("쿼리·프래그먼트가 붙어도 목적지는 그대로다 — 공유 경로에서 utm 이 붙는다", arguments: [
        "https://gguk.org/r/AB12?utm_source=kakao",
        "https://gguk.org/r/AB12#section"
    ])
    func ignoresQueryAndFragment(_ raw: String) {
        #expect(parser.parse(URL(string: raw)!) == .invite(code: "AB12"))
    }

    // 퍼센트 인코딩은 쪼갠 뒤에 푼다. 이 단언들이 없으면 목적지가 늘어 세그먼트 수 가드가 느슨해지는 순간
    // %2F 가 조용히 통과로 바뀐다 — 회귀가 눈에 띄지 않는 종류다.
    @Test("인코딩으로 세그먼트 경계나 코드 내용을 조작할 수 없다", arguments: [
        "https://gguk.org/r/AB%2F12",          // %2F 로 세그먼트를 쪼개려는 시도
        "https://gguk.org/r/AB%2012",          // 공백
        "https://gguk.org/r/AB%0012",          // NUL
        "https://gguk.org/r/AB%E2%80%8B12",    // zero-width space — 화면에서 AB12 와 구별되지 않는다
        "https://gguk.org/r/%E2%80%AEAB12"    // RTL override
    ])
    func rejectsEncodedTampering(_ raw: String) {
        #expect(parser.parse(URL(string: raw)!) == nil)
    }

    @Test("코드 길이 상한을 넘으면 버린다")
    func rejectsOversizedCode() {
        let long = String(repeating: "A", count: Deeplink.maxSegmentLength + 1)

        #expect(parser.parse(URL(string: "gguk://r/\(long)")!) == nil)
    }

    @Test("경로 형태의 흔한 변형은 받아준다", arguments: [
        "https://gguk.org/r/AB12/",        // 후행 슬래시
        "https://gguk.org//r//AB12",       // 빈 세그먼트
        "https://gguk.org:8443/r/AB12"    // 포트
    ])
    func acceptsCommonPathVariants(_ raw: String) {
        #expect(parser.parse(URL(string: raw)!) == .invite(code: "AB12"))
    }

    // AASA 에 www 를 거는지 미정이라, 지금 판정을 고정만 해둔다. 넓히기로 하면 이 단언을 뒤집는다.
    @Test("호스트가 정확히 일치하지 않으면 버린다", arguments: [
        "https://www.gguk.org/r/AB12",     // www — AASA 결정에 따라 뒤집힐 수 있다
        "https://gguk.org./r/AB12",       // FQDN 후행 점
        "https://gguk%2Eorg/r/AB12"       // 인코딩된 점 — 디코드된 host 로 비교하면 통과해버린다
    ])
    func rejectsHostVariants(_ raw: String) {
        #expect(parser.parse(URL(string: raw)!) == nil)
    }

    @Test("우리 것이 아닌 URL 은 버린다", arguments: [
        "https://evil.app/r/AB12",     // 남의 호스트
        "http://gguk.org/r/AB12",      // https 가 아님
        "other://r/AB12"              // 남의 스킴
    ])
    func rejectsForeignURL(_ raw: String) {
        #expect(parser.parse(URL(string: raw)!) == nil)
    }

    @Test("모르는 경로나 불완전한 코드는 버린다", arguments: [
        "https://gguk.org/unknown/AB12",    // 모르는 목적지
        "https://gguk.org/r",          // 코드 없음
        "https://gguk.org/r/",         // 빈 코드
        "https://gguk.org/r/AB12/x",   // 세그먼트 초과
        "https://gguk.org",                 // 경로 없음
        "gguk://r"                    // 코드 없음
    ])
    func rejectsMalformedPath(_ raw: String) {
        #expect(parser.parse(URL(string: raw)!) == nil)
    }
}
