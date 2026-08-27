import DesignSystem
import Foundation
import SwiftUI

/// ⑨ 장소 썸네일 Carousel — 출처 게시글의 사진을 240pt 정사각으로 늘어놓는다.
/// 두 장 이상이면 가로 스크롤로 넘겨 본다(시안 005-2-1: 240 + 간격 12, 다음 장이 살짝 걸친다).
struct PlaceDetailPhotoCarousel: View {
    let photos: [URL]

    private static let side: CGFloat = 240
    private static let spacing: CGFloat = 12
    private static let cornerRadius: CGFloat = 21.5   // 시안 `--md` = 21.486

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Self.spacing) {
                ForEach(Array(photos.enumerated()), id: \.offset) { index, url in
                    photo(url)
                        .accessibilityIdentifier("PlaceDetail.photo.\(index)")
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .accessibilityIdentifier("PlaceDetail.photos")
    }

    private func photo(_ url: URL) -> some View {
        AsyncImage(url: url) { phase in
            if case .success(let image) = phase {
                image.resizable().scaledToFill()
            } else {
                // 로딩 중과 실패를 같은 자리표로 받는다 — 어느 쪽이든 자리가 비면 옆 사진이 밀려
                // 스크롤 위치가 흔들린다.
                placeholder
            }
        }
        .frame(width: Self.side, height: Self.side)
        .clipShape(shape)
        .overlay { shape.strokeBorder(.mhLineNormalAlternative, lineWidth: 1) }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
    }

    private var placeholder: some View {
        Rectangle()
            .fill(.mhFillNormal)
            .overlay {
                Image(systemName: "photo")
                    .font(.system(size: 44))
                    .foregroundStyle(.mhLabelDisable)
            }
    }
}

#Preview {
    PlaceDetailPhotoCarousel(photos: PlaceDetailPlace.sample.photos)
}
