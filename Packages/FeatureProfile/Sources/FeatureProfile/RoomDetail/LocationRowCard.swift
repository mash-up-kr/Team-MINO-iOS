import DesignSystem
import SwiftUI

/// 리스트형 카드 — 좌측 썸네일 1장 + 우측 텍스트/메타. Figma `Card_Location A`.
struct LocationRowCard: View {
    let location: RoomDetailLocation
    let onMore: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoomDetailThumbnail()
                .frame(width: 94)

            VStack(alignment: .leading, spacing: 24) {
                titleRow
                metaRow
            }
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .contain)
    }

    private var titleRow: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(location.name)
                    .mhTypography(.body1NormalBold)
                    .foregroundStyle(.mhLabelNormal)
                Text(location.address)
                    .mhTypography(.label2Medium)
                    .foregroundStyle(.mhLabelAlternative)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            RoomDetailPlainIconButton(
                icon: .moreVerticalTight,
                size: 18,
                accessibilityLabel: "\(location.name) 더보기",
                action: onMore
            )
            .frame(width: 18, height: 18)
        }
    }

    private var metaRow: some View {
        HStack(spacing: 0) {
            RoomDetailMetric(icon: .bubble, text: location.commentCount)
            Spacer(minLength: 8)
            RoomDetailAvatarGroup(count: 1)
        }
    }
}

#Preview {
    LocationRowCard(location: RoomDetailLocation.samples[0]) {}
        .padding(.horizontal, 20)
}
