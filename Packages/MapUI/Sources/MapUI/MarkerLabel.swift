import Foundation

/// 핀 아래 장소명 표기 규칙.
///
/// PRD 「커스텀 핀 마커」 — *"**핀 아래 장소명 표기**: **최대 2줄**까지 노출하며 **한 줄은 7자
/// 기준으로 줄바꿈**한다. 장소명이 **14자를 초과하면 2번째 줄에서 13자 + `...`** 로 말줄임한다."*
///
/// 순수 계산이라 macOS 호스트에서 테스트된다 — 그림은 `MapView` 가 그린다(`UIImage` 는 경계 밖으로
/// 내보내지 않는다는 ``MapMarkerStyle`` 의 규칙과 같은 이유).
///
/// **글자 수는 `Character` 로 센다.** 한글 기준 규칙이라 UTF-16 단위(`String.utf16.count`)로 세면
/// 같은 7자가 다르게 잘린다.
public enum MarkerLabel {
    /// 한 줄에 담는 글자 수.
    public static let charactersPerLine = 7
    /// 최대 줄 수.
    public static let maxLines = 2
    /// 이 글자 수를 **넘으면** 말줄임한다. 딱 이 수(14자 = 7×2)면 두 줄에 꽉 차므로 자르지 않는다.
    public static let truncationThreshold = charactersPerLine * maxLines
    /// 말줄임할 때 남기는 글자 수. 2번째 줄이 `13 − 7 = 6`자 + `...` 가 된다.
    public static let truncatedLength = 13

    /// 마커에 그릴 줄들. 빈 이름이면 빈 배열이라 라벨을 그리지 않는다.
    public static func lines(for name: String) -> [String] {
        let characters = Array(name)
        guard !characters.isEmpty else { return [] }

        guard characters.count > truncationThreshold else {
            // 14자 이하 — 7자씩 끊어 최대 2줄. 8자면 "7자 + 1자" 로 두 줄이 된다.
            return stride(from: 0, to: characters.count, by: charactersPerLine).map { start in
                String(characters[start ..< min(start + charactersPerLine, characters.count)])
            }
        }

        // 14자 초과 — 2번째 줄을 13자에서 끊고 말줄임표를 붙인다.
        return [
            String(characters[0 ..< charactersPerLine]),
            String(characters[charactersPerLine ..< truncatedLength]) + "...",
        ]
    }
}
