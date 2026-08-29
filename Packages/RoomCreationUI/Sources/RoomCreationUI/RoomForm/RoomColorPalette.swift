import DesignSystem
import Domain
import SwiftUI

/// 방 색상 12색. 순서는 피그마 4열×3행 그리드(좌→우, 상→하)와 동일하다.
///
/// **피커 칸(채움·테두리)과 도메인 값(``RoomColor``)을 한 배열이 묶는다.** 따로 두면 순서가
/// 어긋나는 순간 "고른 색과 저장된 색이 다른" 상태가 조용히 만들어진다 — 컴파일도 테스트도
/// 통과한 채로. 썸네일 색은 이 배열이 아니라 ``thumbnail(for:)`` 이 단독으로 짝짓는다.
///
/// 채움·테두리는 Figma `Atomic/*` 팔레트를 그대로 쓴다(사용자가 고르는 팔레트라 역할이 없어
/// 시맨틱 토큰이 맞지 않는다). 계열마다 밝은 단계가 채움, 진한 단계가 테두리다.
public enum RoomColorPalette {
    public struct Entry: Sendable {
        let fill: Color
        let border: Color
        /// 서버와 주고받는 값.
        public let color: RoomColor
    }

    public static let entries: [Entry] = [
        Entry(fill: .mhRed60, border: .mhRed40, color: .red),
        Entry(fill: .mhRedOrange70, border: .mhRedOrange40, color: .redOrange),
        Entry(fill: .mhOrange70, border: .mhOrange40, color: .orange),
        Entry(fill: .mhLime80, border: .mhLime37, color: .lime),
        Entry(fill: .mhGreen90, border: .mhGreen40, color: .green),
        Entry(fill: .mhCyan90, border: .mhCyan40, color: .cyan),
        Entry(fill: .mhViolet80, border: .mhViolet50, color: .violet),
        Entry(fill: .mhPink90, border: .mhPink60, color: .pink),
        Entry(fill: .mhBlue65, border: .mhBlue40, color: .blue),
        Entry(fill: .mhBrown70, border: .mhBrown40, color: .brown),
        Entry(fill: .mhLightBlue60, border: .mhLightBlue40, color: .lightBlue),
        Entry(fill: .mhPurple70, border: .mhPurple40, color: .purple),
    ]

    /// 피커(``MHSelectionGrid``)에 넘길 칸 목록.
    static let gridItems: [MHSelectionGridItem] = entries.map { .color(fill: $0.fill, border: $0.border) }

    /// 인덱스 → 썸네일 색. 범위 밖이면 `nil`(색을 아직 안 골랐거나 잘못된 인덱스).
    public static func thumbnail(at index: Int) -> MHRoomThumbnailColor? {
        color(at: index).flatMap(thumbnail(for:))
    }

    /// 인덱스 → 서버로 보낼 방 색. 범위 밖이면 `nil`.
    public static func color(at index: Int) -> RoomColor? {
        entries.indices.contains(index) ? entries[index].color : nil
    }

    /// 방 색 → 피커 인덱스. 편집 진입처가 방의 색을 폼의 `selectedColorIndex` 로 옮길 때 쓴다.
    public static func index(of color: RoomColor) -> Int? {
        entries.firstIndex { $0.color == color }
    }

    /// 방 색 → 썸네일 색. 방 리스트·저장 시트가 도메인 값을 그림으로 옮길 때 쓴다.
    /// 색 미선택(`gray`)은 그릴 일러스트가 없어 `nil` — 호출부가 my-room 썸네일로 폴백한다.
    ///
    /// 두 enum 의 rawValue 가 같다는 데 기대지 않고 명시적으로 짝짓는다 — `init(rawValue:)` 로
    /// 이으면 한쪽 이름이 바뀌어도 컴파일이 통과하고 런타임에 색이 사라진다.
    public static func thumbnail(for color: RoomColor) -> MHRoomThumbnailColor? {
        switch color {
        case .red: .red
        case .redOrange: .redOrange
        case .orange: .orange
        case .lime: .lime
        case .green: .green
        case .cyan: .cyan
        case .lightBlue: .lightBlue
        case .blue: .blue
        case .violet: .violet
        case .pink: .pink
        case .purple: .purple
        case .brown: .brown
        case .gray: nil
        }
    }
}
