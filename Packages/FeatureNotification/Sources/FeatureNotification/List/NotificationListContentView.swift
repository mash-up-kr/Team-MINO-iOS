import DesignSystem
import Domain
import SwiftUI

/// 알림 탭 목록 콘텐츠. Figma `007-1-1 알림`(node 3037:90987, 배너 미노출 목록) ·
/// `007-1-1 알림_알림 비활성`(node 2652:71189, 배너 노출 목록 — 카드 배치 대조용).
///
/// Store 를 모르는 순수 뷰 — 표시 모델(`notifications`)만 입력으로 받는다(``RoomListContentView`` 선례).
/// **목록만 그린다.** 빈 상태·로딩·실패는 ``NotificationListContainerView`` 가 phase 로 갈라
/// 각각 다른 부품(``MHIllustratedMessage``·``MHStatusMessage``)에 맡기므로, 이 뷰에 항목이
/// 없는 채로 들어오는 경로는 없다.
struct NotificationListContentView: View {
    let notifications: [NotificationListItem]
    let onSelectNotification: ((NotificationListItem.ID) -> Void)?

    /// 목록 마지막 셀이 화면에 나타났을 때(무한스크롤 트리거) 호출된다. `onSelectNotification` 과
    /// 같은 성격의 호출부 주입 슬롯이다.
    let onScrollToEnd: (() -> Void)?

    init(
        notifications: [NotificationListItem],
        onSelectNotification: ((NotificationListItem.ID) -> Void)? = nil,
        onScrollToEnd: (() -> Void)? = nil
    ) {
        self.notifications = notifications
        self.onSelectNotification = onSelectNotification
        self.onScrollToEnd = onScrollToEnd
    }

    var body: some View {
        VStack(spacing: 0) {
            NotificationListHeader()
            list
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.mhBackgroundNormalNormal)
    }

    // Figma Frame 502(node 3037:91006): 셀 375×80, 구분선 없음, 좌우 인셋 없이 셀이 풀폭.
    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(notifications) { item in
                    NotificationCellRow(
                        title: item.title,
                        subtitle: item.subtitle,
                        time: item.time,
                        imageURL: item.imageURL
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { onSelectNotification?(item.id) }
                    // 갈 곳이 없는 셀은 버튼이 아니다 — 트레잇을 붙이면 VoiceOver 가 "버튼" 이라
                    // 읽어 주고 아무 일도 안 일어난다.
                    .accessibilityAddTraits(item.destination == .unresolved ? [] : .isButton)
                    .accessibilityIdentifier("Notification.cell.\(item.id)")
                    .onAppear {
                        guard item.id == notifications.last?.id else { return }
                        onScrollToEnd?()
                    }
                }
            }
        }
        .accessibilityIdentifier("Notification.list")
    }
}

// MARK: - Preview

#Preview("NotificationList") {
    NotificationListContentView(notifications: [
        NotificationListItem(
            id: "1", title: "이미 저장해둔 곳이에요", subtitle: "연남동 스탠딩 커피",
            time: "방금", imageURL: nil, destination: .place(pinID: PinID("pin-1"))
        ),
        NotificationListItem(
            id: "2", title: "장소를 저장하지 못했어요.", subtitle: "잠시 후 다시 시도해주세요",
            time: "1시간 전", imageURL: nil, destination: .saveError
        ),
        NotificationListItem(
            id: "3", title: "지은님이 들어왔어요", subtitle: "언젠가 가야지 방",
            time: "7일 전", imageURL: nil, destination: .room(roomID: "room-1")
        ),
    ])
}
