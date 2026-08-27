import Domain
import Foundation

// MARK: - NotificationListItem (표시 모델)

/// 알림 목록 표시 모델(``PlaceDetailPlace`` 선례).
///
/// `public` 인 이유: 탭 루트 Store 의 상태인 ``NotificationListState`` 가 `public` 이고 이 모델을
/// 필드로 직접 들어서, 공개 표면에 함께 끌려 나온다.
public struct NotificationListItem: Identifiable, Equatable {
    /// 셀 탭 시 이동할 목적지 힌트. 실제 라우팅은 Store/Coordinator 영역이라 여기서는 종류만 구분한다.
    public enum Destination: Equatable {
        /// 장소 상세로 이동(중복 저장·위치 리마인드·코멘트 리마인드). 탭 밖 이동이라 이번 PR 범위 밖(`[SYS-004]` 없음).
        case place
        /// 공동방 상세로 이동(참가 알림). 탭 밖 이동이라 이번 PR 범위 밖.
        case room
        /// 저장 오류 안내 화면으로 push (FR-010). 열 장소가 없어 `.place` 와 다르다 —
        /// `NotificationSaveErrorView.swift` 가 이 목적지의 화면이다.
        case saveError
    }

    public let id: String
    public let title: String
    public let subtitle: String
    public let time: String
    /// 장소 대상 알림 중 대표 이미지가 있는 경우에만 non-nil(FR-012). `nil` 이면 기본 아이콘 썸네일 —
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
    /// `AppNotification` → 표시 모델 매핑. 유형 6종 → 문구 매핑(FR-004)과 썸네일 갈래(FR-012)를
    /// payload 종류로 가른다.
    /// [Convention] .claude/docs/mvi-coordinator-di.md §5 — `PlaceDetailPlace(from:now:)` 선례.
    ///
    /// `.unknown` 유형은 여기 도달하지 않는다 — reduce 가 목록에 담기 전에 거른다.
    public init(from notification: AppNotification, now: Date) {
        let time = NotificationElapsedTime.text(since: notification.createdAt, now: now)
        let id = notification.id.value

        switch notification.type {
        case .duplicateSave:
            self.init(
                id: id, title: "이미 저장해둔 곳이에요", subtitle: Self.placeName(notification.payload),
                time: time, imageURL: Self.placeImageURL(notification.payload), destination: .place
            )
        case .saveError:
            self.init(
                id: id, title: "장소를 저장하지 못했어요.", subtitle: "잠시 후 다시 시도해주세요",
                time: time, imageURL: nil, destination: .saveError
            )
        case .nearbyReminder:
            self.init(
                id: id, title: "근처에 저장한 장소가 있어요", subtitle: Self.placeName(notification.payload),
                time: time, imageURL: Self.placeImageURL(notification.payload), destination: .place
            )
        case .commentReminder:
            self.init(
                id: id, title: "코멘트가 제일 많이 달린 장소에요", subtitle: Self.placeName(notification.payload),
                time: time, imageURL: Self.placeImageURL(notification.payload), destination: .place
            )
        case .memberJoined:
            let (roomName, participantName) = Self.roomInfo(notification.payload)
            self.init(
                id: id, title: "\(participantName)님이 들어왔어요", subtitle: roomName,
                time: time, imageURL: nil, destination: .room
            )
        case .roomJoined:
            let (roomName, _) = Self.roomInfo(notification.payload)
            self.init(
                id: id, title: "방에 참가했어요", subtitle: roomName,
                time: time, imageURL: nil, destination: .room
            )
        case .unknown:
            // reduce 가 이미 걸러 여기 도달하지 않지만, 타입이 이를 보증하지 않아 방어적으로 채운다.
            self.init(id: id, title: "", subtitle: "", time: time, imageURL: nil, destination: .room)
        }
    }

    private static func placeName(_ payload: NotificationPayload) -> String {
        guard case .place(let name, _, _) = payload else { return "" }
        return name
    }

    private static func placeImageURL(_ payload: NotificationPayload) -> URL? {
        guard case .place(_, let imageURL, _) = payload else { return nil }
        return imageURL
    }

    private static func roomInfo(_ payload: NotificationPayload) -> (name: String, participantName: String) {
        guard case .room(let name, _, let participantName) = payload else { return ("", "") }
        return (name, participantName ?? "")
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
