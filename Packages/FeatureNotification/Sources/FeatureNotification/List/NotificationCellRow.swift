import DesignSystem
import SwiftUI

/// `MHNotificationCell` 을 감싸 `imageURL` 을 `AsyncImage` 로 실제 로딩하는 wrapper.
/// `MHNotificationThumbnail.place` 는 이미 로드된 `Image` 값을 요구해, 비동기 로딩 결과를 값
/// 타입으로 미리 만들어 둘 수 없다. 그래서 표시 모델(`NotificationListItem`)은 `imageURL` 만 들고,
/// `Image` 로의 변환은 뷰 계층인 여기서 일어난다.
///
/// 로딩 전(`.empty`)·실패(`.failure`) 모두 `.icon` 자리표시로 폴백한다.
struct NotificationCellRow: View {
    let title: String
    let subtitle: String
    let time: String
    let imageURL: URL?

    var body: some View {
        if let imageURL {
            AsyncImage(url: imageURL) { phase in
                cell(thumbnail: phase.image.map { .place($0) } ?? .icon)
            }
        } else {
            cell(thumbnail: .icon)
        }
    }

    private func cell(thumbnail: MHNotificationThumbnail) -> some View {
        MHNotificationCell(title: title, subtitle: subtitle, time: time, thumbnail: thumbnail)
    }
}
