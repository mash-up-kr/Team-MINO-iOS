import DesignSystem
import SwiftUI

/// 알림 탭 헤더. 화면 상태 5종(로딩·목록·빈 상태·전체 실패·추가 로드 실패)이 모두 이 헤더를
/// 공유하므로, ``NotificationListContentView`` 와 ``NotificationListContainerView`` 가 함께 쓸 수
/// 있도록 독립 View 로 둔다.
///
/// Figma Frame 303(node 3037:90989): 프레임 높이 114 는 상태바(54, Status Bar 인스턴스) 포함값이다.
/// 이 화면은 시스템 safe area 로 상태바 영역을 이미 확보하므로, safe area 이후 논리 높이는
/// 114 − 54 = 60(``RoomListContentView.header`` 와 동일 규모). 타이틀 top 은 그 60 안에서 64 − 54 = 10.
/// 타이틀 텍스트 박스(41×32)는 lineHeight 32 인 `title3Bold`(24 × 1.334)와 일치한다.
struct NotificationListHeader: View {
    var body: some View {
        HStack(spacing: 0) {
            Text("알림")
                .mhTypography(.title3Bold)
                .foregroundStyle(.mhLabelStrong)
                .accessibilityIdentifier("Notification.title")
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .frame(height: 60, alignment: .top)
    }
}
