import Foundation
import Testing
@testable import Networking

private struct DatedDTO: Decodable, Equatable {
    let createdAt: Date
}

private struct EncodableDTO: Encodable {
    let at: Date
}

@Suite("APIDecoder")
struct APIDecoderTests {
    // 서버 응답 예시가 소수점 이하 초를 포함한다(2026-08-16T07:01:31.566Z).
    // `.iso8601` 내장 전략은 iOS 26 미만에서 이걸 거부하므로 커스텀 전략을 쓴다.
    // 이 테스트는 호스트(macOS)에서 돌아 그 차이를 못 보므로, 값까지 정확히 비교해
    // 전략이 바뀌면 어디서 돌든 깨지게 한다.
    @Test("소수점 이하 초를 값까지 정확히 파싱한다")
    func fractionalSeconds() throws {
        let json = Data(#"{"createdAt":"2026-08-16T07:01:31.566Z"}"#.utf8)
        let dto = try APIDecoder.make().decode(DatedDTO.self, from: json)
        #expect(dto.createdAt.timeIntervalSince1970 == 1786863691.566)
    }

    @Test("소수점이 없는 형식도 파싱한다")
    func withoutFractionalSeconds() throws {
        let json = Data(#"{"createdAt":"2026-08-01T09:00:00Z"}"#.utf8)
        let dto = try APIDecoder.make().decode(DatedDTO.self, from: json)
        #expect(dto.createdAt.timeIntervalSince1970 == 1785574800)
    }

    @Test("파싱할 수 없는 날짜는 epoch 로 뭉개지 않고 오류를 던진다")
    func invalidDateThrows() {
        let json = Data(#"{"createdAt":"2026/08/16 07:01"}"#.utf8)
        #expect(throws: DecodingError.self) {
            try APIDecoder.make().decode(DatedDTO.self, from: json)
        }
    }

    @Test("인코딩도 소수점을 남겨 라운드트립에서 밀리초가 유실되지 않는다")
    func roundTripKeepsMilliseconds() throws {
        let original = Date(timeIntervalSince1970: 1786863691.566)
        let encoded = try APIEncoder.make().encode(EncodableDTO(at: original))
        let text = String(decoding: encoded, as: UTF8.self)
        #expect(text.contains("2026-08-16T07:01:31."))   // 소수점 이하 초가 살아 있다
        #expect(text.hasSuffix("Z\"}"))

        let decoded = try APIDecoder.make().decode(DatedDTO.self, from: Data(
            text.replacingOccurrences(of: "\"at\"", with: "\"createdAt\"").utf8
        ))
        // 밀리초 단위까지 보존된다(부동소수 표현 오차는 1ms 미만).
        #expect(abs(decoded.createdAt.timeIntervalSince1970 - original.timeIntervalSince1970) < 0.001)
    }
}
