import SwiftUI

// MARK: - Room Thumbnail Color

/// ``MHRoomThumbnail`` 의 색상 variant. Figma `Room Thumbnail` Property 1.
///
/// 각 색상은 `{Color}/95` 애터믹 배경과 `Accent/Foreground/{Color}` 시맨틱 테두리로 구성된다.
/// `normal` 은 색상 강조 없이 `Background/Normal/Alternative` 배경만 사용한다.
public enum MHRoomThumbnailColor: Sendable, CaseIterable {
    case pink, purple, violet, blue, lightBlue, cyan
    case green, lime, orange, redOrange, red
    case normal

    /// unselect 배경 + select 배경.
    var fill: Color {
        switch self {
        case .pink:       return .mhPink95
        case .purple:     return .mhPurple95
        case .violet:     return .mhViolet95
        case .blue:       return .mhBlue95
        case .lightBlue:  return .mhLightBlue95
        case .cyan:       return .mhCyan95
        case .green:      return .mhGreen95
        case .lime:       return .mhLime95
        case .orange:     return .mhOrange95
        case .redOrange:  return .mhRedOrange95
        case .red:        return .mhRedOrange95          // Figma: Red 도 Red Orange/95 사용
        case .normal:     return .mhBackgroundNormalAlternative
        }
    }

    /// select 테두리 색. `normal` 은 선택 상태가 없어 `nil`.
    var border: Color? {
        switch self {
        case .pink:       return .mhAccentForegroundPink
        case .purple:     return .mhAccentForegroundPurple
        case .violet:     return .mhAccentForegroundViolet
        case .blue:       return .mhAccentForegroundBlue
        case .lightBlue:  return .mhAccentForegroundLightBlue
        case .cyan:       return .mhAccentForegroundCyan
        case .green:      return .mhAccentForegroundGreen
        case .lime:       return .mhAccentForegroundLime
        case .orange:     return .mhAccentForegroundOrange
        case .redOrange:  return .mhAccentForegroundRedOrange
        case .red:        return .mhAccentForegroundRed
        case .normal:     return nil
        }
    }
}

// MARK: - Room Thumbnail

/// 방의 기본 썸네일. Figma `Room Thumbnail`(node 15852:88708).
///
/// 옅은 색 배경의 둥근 사각형 안에 기본 마스코트 캐릭터를 중앙에 얹는다.
/// 방에 지정 이미지가 없을 때 쓰는 기본 표시다.
///
/// - **색상**: ``MHRoomThumbnailColor`` 로 11색 + `normal`(무채색) 제공.
/// - **선택 상태**: `isSelected = true` 이면 해당 색의 `Accent/Foreground` 테두리를 두른다.
///
/// ```swift
/// MHRoomThumbnail()                                  // Pink unselect 80pt
/// MHRoomThumbnail(color: .violet, isSelected: true)  // Violet select
/// MHRoomThumbnail(color: .lime, size: 48)            // Lime 48pt
/// ```
public struct MHRoomThumbnail: View {
    private let color: MHRoomThumbnailColor
    private let isSelected: Bool
    private let size: CGFloat

    public init(
        color: MHRoomThumbnailColor = .pink,
        isSelected: Bool = false,
        size: CGFloat = 80
    ) {
        self.color = color
        self.isSelected = isSelected
        self.size = size
    }

    // Figma 80pt 기준 비율: radius 18.286, 캐릭터 38.857×50.286(중앙).
    private var radius: CGFloat { size * 18.286 / 80 }
    private var borderWidth: CGFloat { size * 2 / 80 }   // Figma: ~2pt at 80

    public var body: some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(color.fill)
            .frame(width: size, height: size)
            .overlay {
                Image("roomMascot", bundle: .module)
                    .resizable().scaledToFit()
                    .frame(width: size * 38.857 / 80, height: size * 50.286 / 80)
            }
            .overlay {
                if isSelected, let border = color.border {
                    RoundedRectangle(cornerRadius: radius)
                        .strokeBorder(border, lineWidth: borderWidth)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: radius))
    }
}

#Preview("MHRoomThumbnail · unselect") {
    LazyVGrid(columns: Array(repeating: GridItem(.fixed(70), spacing: 10), count: 4), spacing: 10) {
        ForEach(MHRoomThumbnailColor.allCases, id: \.self) { color in
            MHRoomThumbnail(color: color, size: 70)
        }
    }
    .padding()
}

#Preview("MHRoomThumbnail · select") {
    LazyVGrid(columns: Array(repeating: GridItem(.fixed(70), spacing: 10), count: 4), spacing: 10) {
        ForEach(MHRoomThumbnailColor.allCases.filter { $0 != .normal }, id: \.self) { color in
            MHRoomThumbnail(color: color, isSelected: true, size: 70)
        }
    }
    .padding()
}
