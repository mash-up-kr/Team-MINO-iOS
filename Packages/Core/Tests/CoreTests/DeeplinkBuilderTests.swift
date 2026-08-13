import Foundation
import Testing
@testable import Core

private let configuration = DeeplinkConfiguration(scheme: "gguk", host: "gguk.org")
private let builder = DeeplinkBuilder(configuration: configuration)
private let parser = DeeplinkParser(configuration: configuration)

struct DeeplinkBuilderTests {
    @Test("공유용 웹 링크를 만든다")
    func buildsWebURL() {
        #expect(builder.webURL(for: .invite(code: "AB12"))?.absoluteString == "https://gguk.org/r/AB12")
    }

    @Test("앱으로 되돌리는 링크를 만든다")
    func buildsAppURL() {
        #expect(builder.appURL(for: .invite(code: "AB12"))?.absoluteString == "gguk://r/AB12")
    }

    @Test("세그먼트를 깨뜨리는 코드는 링크를 만들지 않는다 — 읽을 수 없는 링크를 뿌리지 않기 위해", arguments: [
        "", "A B", "AB/12"
    ])
    func refusesUnparsableCode(_ code: String) {
        #expect(builder.webURL(for: .invite(code: code)) == nil)
        #expect(builder.appURL(for: .invite(code: code)) == nil)
    }

    @Test("왕복 — 만든 링크는 같은 목적지로 다시 읽힌다", arguments: ["AB12", "abc-123", "가나다"])
    func roundTrips(code: String) throws {
        let deeplink = Deeplink.invite(code: code)

        #expect(try parser.parse(#require(builder.webURL(for: deeplink))) == deeplink)
        #expect(try parser.parse(#require(builder.appURL(for: deeplink))) == deeplink)
    }
}
