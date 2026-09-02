import SwiftUI

/// ``MHNotificationCell`` 썸네일 표현. Figma 알림 카드 6종이 쓰는 두 변형을 담는다(스펙 3.0.0).
public enum MHNotificationThumbnail {
    /// 장소 사진 1장(중복 저장·위치 리마인드·코멘트 리마인드). ``MHThumbnail`` 로 정사각 비율로
    /// 그리고, 셀이 실측 radius(9.8)로 바깥에서 자른다(``MHThumbnail`` 의 `radius: true` 는 12
    /// 고정이라 쓰지 않는다).
    case place(Image)
    /// 저장 오류 알림 전용 — 회색 원 안 느낌표. 서버가 주는 사진이 아니라 **유형이 정하는 도상**이라
    /// `.place` 와 갈라 둔다(시안 `006-1-1` 두 번째 셀, `Thumbnail` 컴포넌트의 이미지 fill).
    case saveError
    /// 사진이 없는 경우(공동방 참가 등) 기본 아이콘.
    ///
    /// > 방 알림은 원래 방 썸네일(사진 콜라주 또는 색상 커버)을 그려야 하는데, 알림 응답이 사진
    /// > URL 한 장만 줘서 아직 표현할 수 없다. 서버가 방 썸네일을 어떤 모양으로 줄지 정해지면
    /// > `MHRoomThumbnailKind` 를 받는 케이스로 대체한다.
    case icon
}

// MARK: - Notification Cell

/// 알림 목록 셀. Figma `Frame 500`(node 2792:96955), 375×80.
///
/// 썸네일(좌, 56×56) + 제목/부제(각 1줄) + 우측 시간으로 구성된 단일 골격이며, 알림 타입 6종
/// (중복 저장·오류 저장·위치 리마인드·코멘트 리마인드·공동방 참가 1/2)이 모두 이 컴포넌트
/// 하나로 렌더링된다 — 타입별 분기는 문구·썸네일 데이터로만 나타나고 컴포넌트 자체는 갈라지지 않는다.
///
/// 시간 문자열(`time`)은 이미 포맷된 값을 받는다("방금"·"3시간 전"·"7일 전"·"8월 10일" 등) —
/// 상대 시간 계산은 "현재 시각" 이라는 외부 상태에 의존해 이 컴포넌트가 순수 뷰로 남기 어렵고,
/// 프리뷰·스냅샷에서 결정적이지 않게 만든다. 계산은 호출부(Feature/표시 모델)에서 한다.
///
/// 셀 전체가 하나의 접근성 요소로 묶이며(`accessibilityLabel` = "제목, 부제, 시간"),
/// `accessibilityIdentifier` 는 이 컴포넌트에 붙이지 않는다 — 목록 화면이 항목별로 부여한다.
///
/// ```swift
/// MHNotificationCell(
///     title: "이미 저장해둔 곳이에요", subtitle: "연남동 스탠딩 커피", time: "방금",
///     thumbnail: .place(placePhoto)
/// )
/// MHNotificationCell(
///     title: "장소를 저장하지 못했어요.", subtitle: "잠시 후 다시 시도해주세요", time: "1시간 전",
///     thumbnail: .icon
/// )
/// ```
public struct MHNotificationCell: View {
    private let title: String
    private let subtitle: String
    private let time: String
    private let thumbnail: MHNotificationThumbnail

    public init(title: String, subtitle: String, time: String, thumbnail: MHNotificationThumbnail) {
        self.title = title
        self.subtitle = subtitle
        self.time = time
        self.thumbnail = thumbnail
    }

    // Figma 실측(80pt 셀 기준): 썸네일 56×56, 썸네일-텍스트 간격 12, 텍스트-시간 간격 24(고정), 시간 폭 48.
    // 텍스트 블록은 Figma 상 195 고정폭이지만, 대부분의 문구가 그보다 짧아 시각 차이가 없어 유연 폭을
    // 유지한다 — 시간 앞 간격은 `Spacer(minLength:)` 대신 **고정 폭 스페이서**(`.frame(width:)`)로 둔다.
    // Figma 값 자체가 "하한"이 아니라 고정 24 이므로, 의도를 그대로 코드에 옮긴다(하한만 두는 `minLength`
    // 는 실측상 문제는 없었지만 "정확히 24"라는 계약을 표현하지 못한다).
    // 시간 자리(48)는 Figma 샘플 문구 기준 실측이지 최대폭 계약이 아니다 — `23시간 전`·`11월 30일` 은
    // `caption1Regular`(12pt)에서 48을 넘는다. `minWidth`로 하한만 두고 `fixedSize` 로 시간 텍스트가
    // 자기 고유 폭을 스스로 확보하게 해, 넘칠 땐 제목/부제 블록이 양보하도록 한다.
    private static let thumbnailSize: CGFloat = 56
    private static let thumbnailRadius: CGFloat = Self.thumbnailSize * 14 / 80
    private static let timeWidth: CGFloat = 48
    private static let thumbnailTextSpacing: CGFloat = 12
    private static let textTimeSpacing: CGFloat = 24

    public var body: some View {
        HStack(alignment: .top, spacing: 0) {
            thumbnailView
            Spacer().frame(width: Self.thumbnailTextSpacing)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .mhTypography(.label1NormalBold)
                    .foregroundStyle(.mhLabelNormal)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(subtitle)
                    .mhTypography(.label1NormalRegular)
                    .foregroundStyle(.mhLabelAlternative)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer().frame(width: Self.textTimeSpacing)
            Text(time)
                .mhTypography(.caption1Regular)
                .foregroundStyle(.mhLabelAlternative)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(minWidth: Self.timeWidth, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(subtitle), \(time)")
    }

    @ViewBuilder private var thumbnailView: some View {
        switch thumbnail {
        case .place(let image):
            // `MHThumbnail` 의 `radius: true` 는 12 고정이라 여기서는 끄고, 셀 실측 radius(9.8)로
            // 바깥에서 자른다.
            MHThumbnail(image, ratio: .square)
                .frame(width: Self.thumbnailSize, height: Self.thumbnailSize)
                .clipShape(RoundedRectangle(cornerRadius: Self.thumbnailRadius))
        case .saveError:
            // 그림 자체가 배경(흰 라운드 사각형)까지 포함한다 — 셀이 따로 배경을 깔지 않는다.
            Image(.saveErrorThumbnail)
                .resizable()
                .frame(width: Self.thumbnailSize, height: Self.thumbnailSize)
                .clipShape(RoundedRectangle(cornerRadius: Self.thumbnailRadius))
        case .icon:
            RoundedRectangle(cornerRadius: Self.thumbnailRadius)
                .fill(.mhFillNormal)
                .frame(width: Self.thumbnailSize, height: Self.thumbnailSize)
                .overlay {
                    MHIcon.image.image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundStyle(.mhLabelDisable)
                }
        }
    }
}

// MARK: - Preview

// 카드 6종 데이터. Figma `007-1-1 알림`(node 3037:90987) 실제 배치 순서 그대로(스펙 3.0.0 —
// 대표(집계) 카드는 목록에서 빠졌다).
private struct MHNotificationCellPreviewItem: Identifiable {
    let id: Int
    let title: String
    let subtitle: String
    let time: String
    let thumbnail: MHNotificationThumbnail
}

private func mhNotificationCellPreviewItems() -> [MHNotificationCellPreviewItem] {
    let photo = Image(systemName: "photo.fill")
    return [
        .init(id: 0, title: "이미 저장해둔 곳이에요", subtitle: "연남동 스탠딩 커피",
              time: "방금", thumbnail: .place(photo)),
        .init(id: 1, title: "장소를 저장하지 못했어요.", subtitle: "잠시 후 다시 시도해주세요",
              time: "1시간 전", thumbnail: .icon),
        .init(id: 2, title: "근처에 저장한 장소가 있어요", subtitle: "강남역 스타벅스",
              time: "1일 전", thumbnail: .place(photo)),
        .init(id: 3, title: "코멘트가 제일 많이 달린 장소에요", subtitle: "연남동 스탠딩 커피",
              time: "7일 전", thumbnail: .place(photo)),
        .init(id: 4, title: "지은님이 들어왔어요", subtitle: "언젠가 가야지 방",
              time: "8월 10일", thumbnail: .icon),
        .init(id: 5, title: "방에 참가했어요", subtitle: "언젠가 가야지 방",
              time: "7월 10일", thumbnail: .icon),
    ]
}

private struct MHNotificationCellPreviewList: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(mhNotificationCellPreviewItems()) { item in
                MHNotificationCell(
                    title: item.title, subtitle: item.subtitle, time: item.time,
                    thumbnail: item.thumbnail
                )
                .accessibilityIdentifier("Notification.cell.\(item.id)")
            }
        }
        .background(.mhBackgroundNormalNormal)
    }
}

#Preview("MHNotificationCell · 카드 6종 (Light)") {
    MHNotificationCellPreviewList()
        .preferredColorScheme(.light)
}

#Preview("MHNotificationCell · 카드 6종 (Dark)") {
    MHNotificationCellPreviewList()
        .preferredColorScheme(.dark)
}
