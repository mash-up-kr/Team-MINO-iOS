import Foundation

/// 방 메모(설명). `maxLength` 자로 자를 뿐 빈 값도 허용한다 — 거부 규칙이 없으므로 init 도 실패하지 않는다.
public struct RoomMemo: Equatable, Hashable, Sendable {
    /// 최대 길이. 화면 글자수 카운터·입력 클램프가 같은 값을 읽는다.
    public static let maxLength = 20

    /// 정규화(클램프)된 값. 트림하지 않는다 — 기존 입력 동작 보존.
    public let value: String

    /// 라이브 입력 정규화 — draft 를 `maxLength` 로 자른다.
    public static func clampedDraft(_ raw: String) -> String {
        String(raw.prefix(maxLength))
    }

    /// 항상 성공 — `maxLength` 클램프만 수행한다.
    public init(_ raw: String) {
        self.value = String(raw.prefix(Self.maxLength))
    }
}
