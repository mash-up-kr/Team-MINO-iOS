import Foundation

/// 사용자 표시 이름. 앞뒤 공백·개행을 제거한 값이 최소 길이 이상이어야 한다.
/// 화면의 라이브 draft 는 String 으로 유지하고, 저장 가능 판정 시점에만 이 타입을 만든다.
/// "한글·영문만" 제약은 아직 미구현 — 화면 안내 문구만 존재한다(규칙이 확정되면 여기에 추가).
public struct Nickname: Equatable, Hashable, Sendable {
    /// 트림된 최소 길이. 화면 안내 문구·저장 활성 판정이 같은 값을 읽는다.
    public static let minLength = 2

    /// 정규화(트림)된 값.
    public let value: String

    /// trim 후 `minLength` 미만이면 nil. 성공 시 트림된 값을 보존한다.
    public init?(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= Self.minLength else { return nil }
        self.value = trimmed
    }
}
