import SwiftUI

/// 프로필 아바타로 쓰는 캐릭터 아트 12종. `Image(_:)` 로 만든다.
///
/// 아이콘(``MHIcon``)과 달리 멀티컬러 원본이라 `.foregroundStyle` 로 틴트되지 않는다.
/// 각 이미지는 파스텔 원 배경까지 포함한 정사각 PNG 라, 원형으로 클립해 그대로 얹으면 된다.
///
/// > 이름이 인덱스인 이유: Figma 인스턴스가 12개 모두 `Avatar/Avatar` 로 같아 캐릭터별 이름이 없다.
/// > 색으로 부르는 것도 정확하지 않다(유사 색이 여럿). **선언 순서가 곧 Figma 그리드 순서(좌→우, 상→하)**이고
/// > 선택 결과가 `Int` 인덱스로 저장되므로, 케이스를 재정렬하면 저장된 선택이 다른 캐릭터를 가리킨다.
public enum MHCharacter: String, CaseIterable, Sendable {
    case character01
    case character02
    case character03
    case character04
    case character05
    case character06
    case character07
    case character08
    case character09
    case character10
    case character11
    case character12
}

public extension Image {
    /// Figma 프로필 캐릭터를 로드한다. 멀티컬러라 템플릿 렌더링이 아니다.
    init(_ character: MHCharacter) {
        self.init(character.rawValue, bundle: .module)
    }
}
