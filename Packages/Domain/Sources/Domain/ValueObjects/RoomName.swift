import Foundation

/// 방 이름. 공백 포함 `maxLength` 자 이내이며, 공백만으로는 만들 수 없다.
/// 라이브 입력은 `clampedDraft` 로 자르고, 생성 가능 판정 시점에만 이 타입을 만든다.
public struct RoomName: Equatable, Hashable, Sendable {
    /// 최대 길이. 화면 안내 문구·입력 클램프가 같은 값을 읽는다.
    public static let maxLength = 15

    /// 정규화(트림 + 클램프)된 값.
    public let value: String

    /// 라이브 입력 정규화 — draft 를 `maxLength` 로 자른다(유효성 판정은 하지 않는다).
    /// TextField 바인딩용이라 String 을 반환한다 — 빈 draft 도 화면에는 유효한 중간 상태다.
    public static func clampedDraft(_ raw: String) -> String {
        String(raw.prefix(maxLength))
    }

    /// trim 결과가 비면 nil. 성공 시 트림 후 `maxLength` 로 클램프한 값을 보존한다.
    public init?(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        self.value = String(trimmed.prefix(Self.maxLength))
    }
}
