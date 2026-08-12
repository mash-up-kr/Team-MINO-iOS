import Foundation

/// 앱이 외부에서 열릴 수 있는 목적지의 전부.
/// 진입 경로(웹 링크·custom scheme·푸시)가 달라도 목적지 표현은 이 타입 하나로 모은다.
public enum Deeplink: Equatable, Sendable {
    /// 공동방 초대 — 초대 코드로 방에 참여한다.
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
        switch segments.first {
        case Self.inviteSegment:
            guard segments.count == 2, Self.isValidCode(segments[1]) else { return nil }
            self = .invite(code: segments[1])
        default:
            return nil
        }
    }

    /// 경로 구분자(`/`)가 섞이면 세그먼트가 쪼개져 왕복이 깨지므로 양쪽에서 함께 막는다.
    static func isValidCode(_ code: String) -> Bool {
        code.nilIfEmpty != nil && !code.contains { $0.isWhitespace || $0 == "/" }
    }
}
