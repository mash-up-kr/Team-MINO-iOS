import Foundation

/// 앱이 외부에서 열릴 수 있는 목적지의 전부.
/// 진입 경로(웹 링크·custom scheme·푸시)가 달라도 목적지 표현은 이 타입 하나로 모은다.
public enum Deeplink: Equatable, Sendable {
    case invite(code: String)
}

// MARK: - 경로 문법

/// 읽기(파서)와 쓰기(빌더)가 같은 문법을 쓰도록 양방향을 한곳에 둔다.
/// 나뉘어 있으면 "우리가 만든 링크를 우리 앱이 못 읽는" 상태가 조용히 생긴다.
extension Deeplink {
    static let inviteSegment = "invite"

    var segments: [String] {
        switch self {
        case .invite(let code): [Self.inviteSegment, code]
        }
    }

    init?(segments: [String]) {
        switch segments.first?.lowercased() {
        case Self.inviteSegment:
            guard segments.count == 2, Self.isValidSegment(segments[1]) else { return nil }
            self = .invite(code: segments[1])
        default:
            return nil
        }
    }

    /// 초대 코드의 **형식**은 서버 스펙이 없어 강제하지 않는다. 스펙과 무관하게 참인 것만 막는다 —
    /// 세그먼트를 쪼개는 문자(`/`·공백)와, 눈에 보이지 않아 사람이 링크를 눈으로 검증할 수 없게 만드는
    /// 제어·zero-width 문자(`AB<U+200B>12` 는 화면에서 `AB12` 와 구별되지 않는다).
    static func isValidSegment(_ segment: String) -> Bool {
        guard !segment.isEmpty, segment.count <= maxSegmentLength else { return false }

        return !segment.unicodeScalars.contains {
            $0 == "/"
                || CharacterSet.whitespacesAndNewlines.contains($0)
                || CharacterSet.controlCharacters.contains($0)
        }
    }

    /// 어떤 코드 형식이 와도 걸리지 않을 만큼 넉넉한 상한 — 형식 규칙이 아니라 과대 입력 방어다.
    static let maxSegmentLength = 256
}
