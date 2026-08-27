import CoreGraphics

/// 픽셀 내용을 보는 렌더의 배율.
///
/// `ImageRenderer` 는 **scale 1 에서 에셋 카탈로그 색을 알파 0 으로** 렌더한다. DS 의 시맨틱
/// 컬러(`Color.mh*`)가 전부 `Color(_:bundle:)` 이라 글자·배경이 통째로 사라진 빈 이미지가 나온다.
/// `.black` 같은 비에셋 색은 scale 1 에서도 정상이라 원인이 잘 드러나지 않는다(scale 2 이상은 정상).
///
/// 크기(`uiImage.size`)만 재는 테스트는 영향이 없지만, **픽셀을 비교·스캔하는 테스트는 scale 1 로
/// 두면 "빈 이미지 == 빈 이미지" 가 되어** 변별력을 잃는다("달라야 하는데 같다"로 실패하거나,
/// 더 나쁘게는 같아야 한다는 단언이 무의미하게 통과한다).
///
/// 그래서 픽셀을 보는 렌더는 이 배율을 쓴다. 좌표로 픽셀을 찍는 경우 pt 좌표에 이 값을 곱한다.
enum RenderScale {
    static let ink: CGFloat = 3
    static var inkInt: Int { Int(ink) }
}
