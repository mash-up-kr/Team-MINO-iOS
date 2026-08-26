import DesignSystem
import SwiftUI

/// 방 색상 12색. 순서는 피그마 4열×3행 그리드(좌→우, 상→하)와 동일하다.
///
/// 피커 칸의 채움·테두리와 **같은 색의 방 썸네일**을 한 배열에 묶는다. 둘을 따로 두면 순서가
/// 어긋나는 순간 "고른 색과 미리보기 썸네일 색이 다른" 상태가 조용히 만들어진다 — 컴파일도
/// 테스트도 통과한 채로.
///
/// 채움·테두리는 Figma `Atomic/*` 팔레트를 그대로 쓴다(사용자가 고르는 팔레트라 역할이 없어
/// 시맨틱 토큰이 맞지 않는다). 계열마다 밝은 단계가 채움, 진한 단계가 테두리다.
public enum RoomColorPalette {
    public struct Entry: Sendable {
        let fill: Color
        let border: Color
        /// 같은 색의 방 썸네일 일러스트(``MHRoomThumbnail``).
        public let thumbnail: MHRoomThumbnailColor
    }

    public static let entries: [Entry] = [
        Entry(fill: .mhRed60, border: .mhRed40, thumbnail: .red),
        Entry(fill: .mhRedOrange70, border: .mhRedOrange40, thumbnail: .redOrange),
        Entry(fill: .mhOrange70, border: .mhOrange40, thumbnail: .orange),
        Entry(fill: .mhLime80, border: .mhLime37, thumbnail: .lime),
        Entry(fill: .mhGreen90, border: .mhGreen40, thumbnail: .green),
        Entry(fill: .mhCyan90, border: .mhCyan40, thumbnail: .cyan),
        Entry(fill: .mhViolet80, border: .mhViolet50, thumbnail: .violet),
        Entry(fill: .mhPink90, border: .mhPink60, thumbnail: .pink),
        Entry(fill: .mhBlue65, border: .mhBlue40, thumbnail: .blue),
        Entry(fill: .mhBrown70, border: .mhBrown40, thumbnail: .brown),
        Entry(fill: .mhLightBlue60, border: .mhLightBlue40, thumbnail: .lightBlue),
        Entry(fill: .mhPurple70, border: .mhPurple40, thumbnail: .purple),
    ]

    /// 피커(``MHSelectionGrid``)에 넘길 칸 목록.
    static let gridItems: [MHSelectionGridItem] = entries.map { .color(fill: $0.fill, border: $0.border) }

    /// 인덱스 → 썸네일 색. 범위 밖이면 `nil`(색을 아직 안 골랐거나 잘못된 인덱스).
    public static func thumbnail(at index: Int) -> MHRoomThumbnailColor? {
        entries.indices.contains(index) ? entries[index].thumbnail : nil
    }

    /// 방 색 hex → 피커 인덱스. 팔레트에 없는 색이면 `nil`.
    ///
    /// 편집 진입처가 방의 `color`(hex) 를 폼의 `selectedColorIndex` 로 옮길 때 쓴다.
    /// hex 해석은 ``MHRoomThumbnailColor/init(roomColorHex:)`` 가 맡는다 — `#` 유무·대소문자를
    /// 무시하고, 색마다 채움·테두리 두 hex 를 모두 받는다.
    public static func index(ofHex hex: String) -> Int? {
        guard let color = MHRoomThumbnailColor(roomColorHex: hex) else { return nil }
        return entries.firstIndex { $0.thumbnail == color }
    }
}
