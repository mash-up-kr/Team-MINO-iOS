import DesignSystem
import SwiftUI

/// `MHNotificationCell` 을 감싸 표시 모델을 썸네일 갈래로 옮기는 wrapper.
///
/// `MHNotificationThumbnail.place` 는 이미 로드된 `Image` 값을 요구해, 비동기 로딩 결과를 값
/// 타입으로 미리 만들어 둘 수 없다. 그래서 표시 모델은 `imageURL` 만 들고, `Image` 로의 변환은
/// 뷰 계층인 여기서 일어난다.
struct NotificationCellRow: View {
    let item: NotificationListItem

    var body: some View {
        switch item.destination {
        case .saveError:
            // 이 유형의 썸네일은 서버가 주는 사진이 아니라 **유형이 정하는 도상**이라
            // `imageURL` 보다 우선한다(기획 ② "썸네일 이미지 = 오류 아이콘").
            cell(thumbnail: .saveError)
        case .place, .room, .unresolved:
            if let imageURL = item.imageURL {
                // 로딩 전(`.empty`)·실패(`.failure`) 는 `.icon` 자리표시로 폴백한다.
                AsyncImage(url: imageURL) { phase in
                    cell(thumbnail: phase.image.map { .place($0) } ?? .icon)
                }
            } else {
                cell(thumbnail: .icon)
            }
        }
    }

    private func cell(thumbnail: MHNotificationThumbnail) -> some View {
        MHNotificationCell(
            title: item.title, subtitle: item.subtitle, time: item.time, thumbnail: thumbnail
        )
    }
}
