import Domain
import Foundation

// MARK: - NotificationListItem (표시 모델)

/// 알림 목록 표시 모델(``PlaceDetailPlace`` 선례).
///
/// `public` 인 이유: 탭 루트 Store 의 상태인 ``NotificationListState`` 가 `public` 이고 이 모델을
/// 필드로 직접 들어서, 공개 표면에 함께 끌려 나온다.
public struct NotificationListItem: Identifiable, Equatable {
    /// 셀 탭 시 이동할 목적지. 조회에 쓸 식별자까지 들고 있다 — reduce 가 이 값만 보고 조회를 낸다.
    public enum Destination: Equatable {
        /// 장소 상세로 이동(중복 저장·위치 리마인드·코멘트 리마인드). 저장 탭에서 연다.
        case place(pinID: PinID)
        /// 공동방 상세로 이동(참가 알림). 저장 탭에서 연다.
        case room(roomID: String)
        /// 저장 오류 안내 화면으로 push (FR-010). 알림 탭 안에서 열려 식별자가 필요 없다 —
        /// `NotificationSaveErrorView.swift` 가 이 목적지의 화면이다.
        case saveError
        /// 이동에 쓸 식별자를 서버가 주지 않았을 때. **셀은 그대로 그리되 탭해도 아무 일도 하지
        /// 않는다** — 문구는 서버가 완성해서 주므로 식별자가 없어도 셀 내용은 멀쩡하다.
        case unresolved
    }

    public let id: String
    public let title: String
    public let subtitle: String
    public let time: String
    /// 서버가 준 썸네일. 없으면 `nil` 이고 기본 아이콘 썸네일이 그려진다(FR-012) —
    /// 실제 `Image` 로딩(`AsyncImage`)은 이 값을 받는 View 계층(``NotificationCellRow``)이 맡는다
    /// (비동기 로딩 결과를 값 타입으로 미리 만들어 둘 수 없다 — ``NotificationCellRow`` 주석).
    public let imageURL: URL?
    public let destination: Destination

    public init(
        id: String,
        title: String,
        subtitle: String,
        time: String,
        imageURL: URL?,
        destination: Destination
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.time = time
        self.imageURL = imageURL
        self.destination = destination
    }
}

extension NotificationListItem {
    /// `AppNotification` → 표시 모델 매핑.
    /// [Convention] .claude/docs/mvi-coordinator-di.md §5 — `PlaceDetailPlace(from:now:)` 선례.
    ///
    /// **문구를 만들지 않는다.** 유형별 문구는 서버가 `typeLabel` 로 완성해서 주므로 그대로 옮긴다.
    /// 앱이 만드는 건 경과시간 표기 하나뿐이다 — 서버는 `createdAt` 만 준다.
    public init(from notification: AppNotification, now: Date) {
        self.init(
            id: notification.id.value,
            title: notification.title,
            subtitle: notification.targetName,
            time: NotificationElapsedTime.text(since: notification.createdAt, now: now),
            imageURL: notification.thumbnailURL,
            destination: Destination(notification.destination)
        )
    }
}

private extension NotificationListItem.Destination {
    init(_ destination: NotificationDestination) {
        switch destination {
        case .place(let pinID): self = .place(pinID: pinID)
        case .room(let roomID): self = .room(roomID: roomID)
        case .saveError: self = .saveError
        case .unresolved: self = .unresolved
        }
    }
}

// MARK: - NotificationElapsedTime

/// FR-003 경과시간 포맷 — 1시간 미만 `방금` / 24시간 미만 `N시간 전` / 7일 미만 `N일 전` /
/// 그 이상 `N월 N일`(연도 미포함). ``PlaceDetailSaveAge`` 처럼 매핑과 분리된 순수 함수로 둬
/// 시간 계산만 독립적으로 경계값 테스트한다.
enum NotificationElapsedTime {
    private static let hour: TimeInterval = 3600
    private static let day: TimeInterval = 24 * 3600
    private static let week: TimeInterval = 7 * 24 * 3600

    /// SC-005 경계값: 59분 / 60분 / 23시간59분 / 24시간 / 6일23시간 / 7일.
    static func text(since createdAt: Date, now: Date, calendar: Calendar = .current) -> String {
        let elapsed = now.timeIntervalSince(createdAt)
        if elapsed < hour {
            return "방금"
        } else if elapsed < day {
            return "\(Int(elapsed / hour))시간 전"
        } else if elapsed < week {
            return "\(Int(elapsed / day))일 전"
        } else {
            let components = calendar.dateComponents([.month, .day], from: createdAt)
            return "\(components.month ?? 0)월 \(components.day ?? 0)일"
        }
    }
}
