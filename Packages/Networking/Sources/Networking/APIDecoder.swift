import Foundation

/// API 디코딩 규칙의 단일 출처. Repository 마다 `JSONDecoder` 를 새로 만들지 않는다.
public enum APIDecoder {
    public static func make() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(Self.decodeISO8601)
        return decoder
    }

    /// 서버는 `format: date-time` 만 약속하고 소수점 이하 초의 유무는 정하지 않는다
    /// (실제 응답 예시는 `2026-08-16T07:01:31.566Z` 로 소수점이 붙는다). 그래서 둘 다 받는다.
    ///
    /// **`JSONDecoder.dateDecodingStrategy = .iso8601` 을 쓰면 안 된다** — 그 전략은
    /// iOS 26 미만에서 소수점이 붙은 문자열을 거부한다(iOS 17·18 실측). 배포 타깃이 iOS 17 이라
    /// 호스트(macOS)에서만 테스트하면 통과하고 기기에서 전멸한다.
    /// ⚠️ **이 폴백은 호스트(macOS) 테스트로 검증되지 않는다.** 호스트의 `fractional` 스타일은
    /// 소수점이 **없는** 문자열까지 파싱해서, `plain` 을 지워도 `swift test` 가 전부 통과한다.
    /// iOS 에서는 둘이 갈리므로 **호스트 테스트만으로는 이 폴백이 지켜지지 않는다.**
    /// 시뮬레이터에서 돌리는 CI 잡이 후속으로 필요하다(토큰 권한 문제로 이번 PR 에서 제외).
    private static func decodeISO8601(_ decoder: any Decoder) throws -> Date {
        let raw = try decoder.singleValueContainer().decode(String.self)
        if let date = try? Date(raw, strategy: fractional) { return date }
        if let date = try? Date(raw, strategy: plain) { return date }
        throw DecodingError.dataCorrupted(
            .init(
                codingPath: decoder.codingPath,
                debugDescription: "ISO8601 날짜가 아님: \(raw)"
            )
        )
    }

    // ISO8601FormatStyle 은 값 타입이라 Sendable 이다(ISO8601DateFormatter 는 아니다).
    static let fractional = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    static let plain = Date.ISO8601FormatStyle(includingFractionalSeconds: false)
}

/// 요청 본문 인코딩 규칙의 단일 출처.
public enum APIEncoder {
    public static func make() -> JSONEncoder {
        let encoder = JSONEncoder()
        // 디코딩이 소수점을 받으므로 인코딩도 맞춰 라운드트립에서 밀리초가 유실되지 않게 한다.
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(APIDecoder.fractional.format(date))
        }
        return encoder
    }
}
