import DesignSystem
import SwiftUI

/// 카드형 카드 — 텍스트 위, 썸네일 2장 아래. Figma `Card_Location B`.
struct LocationGridCard: View {
    let location: RoomDetailLocation
    let onMore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            titleRow
            photoRow
            metaRow
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .contain)
    }

    private var titleRow: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(location.name)
                    .mhTypography(.body1NormalBold)
                    .foregroundStyle(.mhLabelNormal)
                    .lineLimit(1)
                Text(location.address)
                    .mhTypography(.label2Medium)
                    .foregroundStyle(.mhLabelAlternative)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            RoomDetailPlainIconButton(
                icon: .moreVerticalTight,
                accessibilityLabel: "\(location.name) 더보기",
                action: onMore
            )
            .frame(width: 24, height: 24)
        }
    }

    private var photoRow: some View {
        HStack(spacing: 8) {
            ForEach(0..<max(location.photoCount, 1), id: \.self) { _ in
                RoomDetailThumbnail(ratio: .r4x5)
            }
        }
    }

    private var metaRow: some View {
        HStack(spacing: 0) {
            RoomDetailMetric(icon: .bubble, text: location.commentCount, iconSize: 24)
                .padding(.leading, 2)
            Spacer(minLength: 8)
            RoomDetailAvatarGroup(count: 1)
        }
    }
}

#Preview {
    LocationGridCard(location: RoomDetailLocation.samples[0]) {}
        .padding(.horizontal, 20)
}
