import SwiftUI

// MARK: - Room Thumbnail

/// 방의 기본 썸네일. Figma `Room Thumbnail`(node 15852:88708).
///
/// 옅은 핑크 배경의 둥근 사각형 안에 기본 마스코트 캐릭터를 중앙에 얹는다. 방에 지정 이미지가 없을 때
/// 쓰는 기본 표시다(지정 이미지 슬롯은 아직 미정 — 마스코트만 제공).
///
/// > 배경색은 Figma atomic `Pink/95`(#FEECFB) — 시맨틱 토큰이 없어 `AtomicColor.xcassets` 에 에셋으로
/// > 등록해 `.mhPink95` 로 쓴다(hex 직접 사용 금지).
///
/// ```swift
/// MHRoomThumbnail()            // 80pt
/// MHRoomThumbnail(size: 48)
/// ```
public struct MHRoomThumbnail: View {
    private let size: CGFloat

    public init(size: CGFloat = 80) { self.size = size }

    // Figma 80pt 기준 비율: radius 18.286, 캐릭터 38.857×50.286(중앙).
    private var radius: CGFloat { size * 18.286 / 80 }

    public var body: some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(.mhPink95)   // Figma atomic Pink/95
            .frame(width: size, height: size)
            .overlay {
                Image("roomMascot", bundle: .module)
                    .resizable().scaledToFit()
                    .frame(width: size * 38.857 / 80, height: size * 50.286 / 80)
            }
            .clipShape(RoundedRectangle(cornerRadius: radius))
    }
}

#Preview("MHRoomThumbnail") {
    HStack(spacing: 16) {
        MHRoomThumbnail()
        MHRoomThumbnail(size: 56)
        MHRoomThumbnail(size: 40)
    }
    .padding()
}
