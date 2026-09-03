import DesignSystem
import Domain
import Testing
@testable import FeatureHome

/// 방 캐릭터는 **보고 있는 방**을 나타낸다(FR-021) — 색이 하나라도 빠지면 방을 옮겼을 때
/// 엉뚱한 소품이 따라온다. 팔레트가 늘어날 때 이 테스트가 먼저 깨지도록 전 케이스를 건다.
struct HomeMascotPaletteTests {

    @Test("색을 고르지 않은 방과 색을 모르는 방은 소품 없는 기본 마스코트다")
    func grayAndUnknownFallBackToPlain() {
        #expect(HomeMascotPalette.mascot(of: .gray) == .plain)
        #expect(HomeMascotPalette.mascot(of: nil) == .plain)
    }

    @Test("gray 를 뺀 12색은 저마다 다른 마스코트를 얻는다")
    func twelveColorsMapToDistinctMascots() {
        let colored = RoomColor.allCases.filter { $0 != .gray }
        #expect(colored.count == 12)

        let mascots = colored.map(HomeMascotPalette.mascot(of:))
        #expect(!mascots.contains(.plain))          // 색이 있는 방에 기본 그림이 떨어지면 안 된다
        #expect(Set(mascots).count == colored.count)   // 두 색이 같은 소품을 쓰지 않는다
    }

    @Test(
        "각 방 색은 같은 이름의 마스코트로 간다",
        arguments: [
            (RoomColor.red, MHHomeMascot.red),
            (.redOrange, .redOrange),
            (.orange, .orange),
            (.lime, .lime),
            (.green, .green),
            (.cyan, .cyan),
            (.lightBlue, .lightBlue),
            (.blue, .blue),
            (.violet, .violet),
            (.pink, .pink),
            (.purple, .purple),
            (.brown, .brown)
        ]
    )
    func colorMapsToSameNamedMascot(color: RoomColor, expected: MHHomeMascot) {
        #expect(HomeMascotPalette.mascot(of: color) == expected)
    }
}
