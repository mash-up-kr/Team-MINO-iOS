import SwiftUI

/// ``MHRoomThumbnail`` 의 색상 variant. Figma `Room Thumbnail` Property 1.
///
/// 각 색상은 `{Color}/95` 애터믹 배경과 `Accent/Foreground/{Color}` 시맨틱 테두리로 구성된다.
/// `normal` 은 색상 강조 없이 `Background/Normal/Alternative` 배경만 사용한다.
public enum MHRoomThumbnailColor: Sendable, CaseIterable, Equatable {
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

// MARK: - Room Thumbnail Kind

/// ``MHRoomThumbnail`` 이 그릴 표현 종류. 색상 마스코트(기존) vs my-room 전용 일러스트(신규)는
/// 배경·radius·이미지 배치가 서로 달라 한 색상 축에 욱여넣지 않고 별도 case 로 가른다.
public enum MHRoomThumbnailKind: Sendable, Equatable {
    /// 색 배경 + 중앙 마스코트. Figma `Room Thumbnail`(node 15852:88708).
    case color(MHRoomThumbnailColor, isSelected: Bool)
    /// my-room 전용 일러스트(edge-to-edge). Figma `Room Thumbnail`(prop1="my room", instance 2242:51242).
    case myRoom
}

/// 방의 기본 썸네일. Figma `Room Thumbnail`.
///
/// 옅은 색 배경의 둥근 사각형 안에 기본 마스코트 캐릭터를 중앙에 얹는 **색상** 표현(node 15852:88708)과,
/// 색 배경 없이 전용 일러스트가 썸네일을 가득 채우는 **my-room** 표현(prop1="my room") 두 가지를 그린다.
/// 방에 지정 이미지가 없을 때 쓰는 기본 표시다.
///
/// - **색상**: ``MHRoomThumbnailColor`` 로 11색 + `normal`(무채색) 제공. `isSelected = true` 면 해당 색의
///   `Accent/Foreground` 테두리를 두른다. radius 18.286(80pt 기준).
/// - **my-room**: 색 토큰 배경 없이 전용 이미지 하나가 edge-to-edge 로 채운다. radius 14(80pt 기준) —
///   색상 표현과 다른 값(Figma 인스턴스 실측).
///
/// ```swift
/// MHRoomThumbnail()                                  // Pink unselect 80pt
/// MHRoomThumbnail(color: .violet, isSelected: true)  // Violet select
/// MHRoomThumbnail(color: .lime, size: 48)            // Lime 48pt
/// MHRoomThumbnail.myRoom()                           // my-room 일러스트 80pt
/// ```
public struct MHRoomThumbnail: View {
    private let kind: MHRoomThumbnailKind
    private let size: CGFloat

    public init(
        color: MHRoomThumbnailColor = .pink,
        isSelected: Bool = false,
        size: CGFloat = 80
    ) {
        self.kind = .color(color, isSelected: isSelected)
        self.size = size
    }

    /// ``MHRoomThumbnailKind`` 를 직접 지정. ``MHRoomCard`` 처럼 썸네일 종류를 주입받는 컨테이너가 쓴다.
    public init(kind: MHRoomThumbnailKind, size: CGFloat = 80) {
        self.kind = kind
        self.size = size
    }

    /// my-room 전용 일러스트 썸네일.
    public static func myRoom(size: CGFloat = 80) -> MHRoomThumbnail {
        MHRoomThumbnail(kind: .myRoom, size: size)
    }

    // Figma 80pt 기준 비율. color: radius 18.286, 캐릭터 38.857×50.286(중앙). myRoom: radius 14.
    // (myRoom 은 80pt 인스턴스 1개만 실측 — 다른 size 로의 비례 스케일은 color 경로와의 일관성을 위한
    // 구현자 판단이며 Figma 로 별도 검증되지 않았다.)
    private var radius: CGFloat {
        switch kind {
        case .color: size * 18.286 / 80
        case .myRoom: size * 14 / 80
        }
    }

    private var borderWidth: CGFloat { size * 2 / 80 }   // Figma: ~2pt at 80 (color 경로 전용)

    public var body: some View {
        switch kind {
        case .color(let color, let isSelected):
            colorBody(color: color, isSelected: isSelected)
        case .myRoom:
            myRoomBody
        }
    }

    @ViewBuilder
    private func colorBody(color: MHRoomThumbnailColor, isSelected: Bool) -> some View {
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

    private var myRoomBody: some View {
        Image("myRoomThumbnail", bundle: .module)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: radius))
    }
}

#Preview("MHRoomThumbnail · unselect") {
    LazyVGrid(columns: Array(repeating: GridItem(.fixed(70), spacing: 10), count: 4), spacing: 10) {
        ForEach(MHRoomThumbnailColor.allCases, id: \.self) { color in
            MHRoomThumbnail(color: color, size: 70)
        }
        MHRoomThumbnail.myRoom(size: 70)
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
