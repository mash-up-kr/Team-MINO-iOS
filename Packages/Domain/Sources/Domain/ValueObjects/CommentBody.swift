import Foundation

/// 코멘트 본문. 제출 시 trim → `maxLength` 클램프 → 빈 값 거부 순으로 정규화한다.
/// 라이브 입력은 자르지 않는다 — 화면 글자수 카운터가 초과를 보여주고, 제출 시점에만 이 타입을 만든다.
public struct CommentBody: Equatable, Hashable, Sendable {
    /// 최대 길이. 화면 글자수 카운터가 같은 값을 읽는다.
    public static let maxLength = 200

    /// 정규화(트림 + 클램프)된 값.
    public let value: String

    /// trim 결과가 비면 nil. 성공 시 `maxLength` 로 클램프한 값을 보존한다.
    public init?(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        self.value = String(trimmed.prefix(Self.maxLength))
    }
}
