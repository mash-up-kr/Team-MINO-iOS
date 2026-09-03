import SwiftUI
import CoreText

// SUITE 는 앱 번들이 아니라 이 패키지 리소스에 있으므로 런타임에 CTFontManager 로 등록한다
// (Info.plist `UIAppFonts` 는 앱 타깃 전용이라 SPM 리소스엔 적용되지 않는다).

public enum MHFontWeight: Sendable {
    case regular, medium, bold

    /// 등록된 SUITE OTF 의 PostScript 이름
    var postScriptName: String {
        switch self {
        case .regular: "SUITE-Regular"
        case .medium:  "SUITE-Medium"
        case .bold:    "SUITE-Bold"
        }
    }

    var uiWeight: UIFont.Weight {
        switch self {
        case .regular: .regular
        case .medium:  .medium
        case .bold:    .bold
        }
    }
}

/// 하나의 텍스트 스타일 토큰. Figma 변수(크기·행간 배수·자간 퍼센트)를 그대로 담는다.
public struct MHTypography: Sendable, Equatable {
    public let weight: MHFontWeight
    public let size: CGFloat
    /// 행간 배수 (Figma lineHeight). 목표 줄높이 = size * lineHeightMultiple
    public let lineHeightMultiple: CGFloat
    /// 자간 퍼센트 (Figma letterSpacing). tracking(pt) = size * percent / 100
    public let letterSpacingPercent: CGFloat

    public init(weight: MHFontWeight, size: CGFloat, lineHeightMultiple: CGFloat, letterSpacingPercent: CGFloat) {
        self.weight = weight
        self.size = size
        self.lineHeightMultiple = lineHeightMultiple
        self.letterSpacingPercent = letterSpacingPercent
    }

    public var font: Font {
        MHFontRegistrar.registerIfNeeded()
        return .custom(weight.postScriptName, fixedSize: size)
    }

    /// 자간(pt)
    public var tracking: CGFloat { size * letterSpacingPercent / 100 }

    /// 목표 줄높이(pt)
    public var lineHeight: CGFloat { size * lineHeightMultiple }
}

extension MHFontWeight: Equatable {}

// MARK: - Adoption

public extension View {
    /// 텍스트 스타일 토큰을 적용한다(폰트·자간·행간). 멀티라인 본문에 권장.
    func mhTypography(_ style: MHTypography) -> some View {
        modifier(MHTypographyModifier(style: style))
    }
}

public extension Text {
    /// 폰트·자간만 적용해 `Text` 를 반환한다(행간 패딩 없음). 버튼 등 컨테이너가 높이를 잡는 단일 라인에 쓴다.
    func mhTypography(_ style: MHTypography) -> Text {
        self.font(style.font).tracking(style.tracking)
    }

    /// 여러 줄 텍스트에 **행간까지** 적용한다(시안 라인박스 = size × lineHeightMultiple).
    ///
    /// `Text` 에 그냥 `.mhTypography` 를 부르면 위의 `Text` 오버로드가 잡혀 폰트·자간만 들어간다 —
    /// 한 줄짜리엔 문제가 없지만 여러 줄이면 SUITE 의 intrinsic 행간(시안보다 좁다)이 그대로 나와
    /// 블록 높이가 시안보다 작아진다(예: Heading 1 2줄 60 → 55). 여러 줄이면 이걸 쓴다.
    /// (`foregroundStyle` 등을 먼저 붙여도 `Text` 가 그대로라 오버로드는 바뀌지 않는다)
    func mhTypographyMultiline(_ style: MHTypography) -> some View {
        modifier(MHTypographyModifier(style: style))
    }
}

struct MHTypographyModifier: ViewModifier {
    let style: MHTypography

    func body(content: Content) -> some View {
        let ui = UIFont(name: style.weight.postScriptName, size: style.size)
            ?? .systemFont(ofSize: style.size, weight: style.weight.uiWeight)
        let extra = max(0, style.lineHeight - ui.lineHeight)
        content
            .font(style.font)
            .tracking(style.tracking)
            .lineSpacing(extra)
            .padding(.vertical, extra / 2)
    }
}

// MARK: - Font registration

enum MHFontRegistrar {
    private static let register: Void = {
        for name in ["SUITE-Regular", "SUITE-Medium", "SUITE-Bold"] {
            guard let url = Bundle.module.url(forResource: name, withExtension: "otf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }()

    static func registerIfNeeded() { _ = register }
}

// MARK: - Tokens (Figma 이름 그대로)

public extension MHTypography {

    /// Figma `Display 1/Bold`
    static let display1Bold = MHTypography(weight: .bold, size: 56, lineHeightMultiple: 1.286, letterSpacingPercent: -3.19)
    /// Figma `Display 1/Medium`
    static let display1Medium = MHTypography(weight: .medium, size: 56, lineHeightMultiple: 1.286, letterSpacingPercent: -3.19)
    /// Figma `Display 1/Regular`
    static let display1Regular = MHTypography(weight: .regular, size: 56, lineHeightMultiple: 1.286, letterSpacingPercent: -3.19)
    /// Figma `Display 2/Bold`
    static let display2Bold = MHTypography(weight: .bold, size: 40, lineHeightMultiple: 1.3, letterSpacingPercent: -2.82)
    /// Figma `Display 2/Medium`
    static let display2Medium = MHTypography(weight: .medium, size: 40, lineHeightMultiple: 1.3, letterSpacingPercent: -2.82)
    /// Figma `Display 2/Regular`
    static let display2Regular = MHTypography(weight: .regular, size: 40, lineHeightMultiple: 1.3, letterSpacingPercent: -2.82)
    /// Figma `Display 3/Bold`
    static let display3Bold = MHTypography(weight: .bold, size: 36, lineHeightMultiple: 1.334, letterSpacingPercent: -2.7)
    /// Figma `Display 3/Medium`
    static let display3Medium = MHTypography(weight: .medium, size: 36, lineHeightMultiple: 1.334, letterSpacingPercent: -2.7)
    /// Figma `Display 3/Regular`
    static let display3Regular = MHTypography(weight: .regular, size: 36, lineHeightMultiple: 1.334, letterSpacingPercent: -2.7)
    /// Figma `Title 1/Bold`
    static let title1Bold = MHTypography(weight: .bold, size: 32, lineHeightMultiple: 1.375, letterSpacingPercent: -2.53)
    /// Figma `Title 1/Medium`
    static let title1Medium = MHTypography(weight: .medium, size: 32, lineHeightMultiple: 1.375, letterSpacingPercent: -2.53)
    /// Figma `Title 1/Regular`
    static let title1Regular = MHTypography(weight: .regular, size: 32, lineHeightMultiple: 1.375, letterSpacingPercent: -2.53)
    /// Figma `Title 2/Bold`
    static let title2Bold = MHTypography(weight: .bold, size: 28, lineHeightMultiple: 1.358, letterSpacingPercent: -2.36)
    /// Figma `Title 2/Medium`
    static let title2Medium = MHTypography(weight: .medium, size: 28, lineHeightMultiple: 1.358, letterSpacingPercent: -2.36)
    /// Figma `Title 2/Regular`
    static let title2Regular = MHTypography(weight: .regular, size: 28, lineHeightMultiple: 1.358, letterSpacingPercent: -2.36)
    /// Figma `Title 3/Bold`
    static let title3Bold = MHTypography(weight: .bold, size: 24, lineHeightMultiple: 1.334, letterSpacingPercent: -2.3)
    /// Figma `Title 3/Medium`
    static let title3Medium = MHTypography(weight: .medium, size: 24, lineHeightMultiple: 1.334, letterSpacingPercent: -2.3)
    /// Figma `Title 3/Regular`
    static let title3Regular = MHTypography(weight: .regular, size: 24, lineHeightMultiple: 1.334, letterSpacingPercent: -2.3)
    /// Figma `Heading 1/Bold`
    static let heading1Bold = MHTypography(weight: .bold, size: 22, lineHeightMultiple: 1.364, letterSpacingPercent: -1.94)
    /// Figma `Heading 1/Medium`
    static let heading1Medium = MHTypography(weight: .medium, size: 22, lineHeightMultiple: 1.364, letterSpacingPercent: -1.94)
    /// Figma `Heading 1/Regular`
    static let heading1Regular = MHTypography(weight: .regular, size: 22, lineHeightMultiple: 1.364, letterSpacingPercent: -1.94)
    /// Figma `Heading 2/Bold`
    static let heading2Bold = MHTypography(weight: .bold, size: 20, lineHeightMultiple: 1.4, letterSpacingPercent: -1.2)
    /// Figma `Heading 2/Medium`
    static let heading2Medium = MHTypography(weight: .medium, size: 20, lineHeightMultiple: 1.4, letterSpacingPercent: -1.2)
    /// Figma `Heading 2/Regular`
    static let heading2Regular = MHTypography(weight: .regular, size: 20, lineHeightMultiple: 1.4, letterSpacingPercent: -1.2)
    /// Figma `Headline 1/Bold`
    static let headline1Bold = MHTypography(weight: .bold, size: 18, lineHeightMultiple: 1.445, letterSpacingPercent: -0.02)
    /// Figma `Headline 1/Medium`
    static let headline1Medium = MHTypography(weight: .medium, size: 18, lineHeightMultiple: 1.445, letterSpacingPercent: -0.02)
    /// Figma `Headline 1/Regular`
    static let headline1Regular = MHTypography(weight: .regular, size: 18, lineHeightMultiple: 1.445, letterSpacingPercent: -0.02)
    /// Figma `Headline 2/Bold`
    static let headline2Bold = MHTypography(weight: .bold, size: 17, lineHeightMultiple: 1.412, letterSpacingPercent: 0.0)
    /// Figma `Headline 2/Medium`
    static let headline2Medium = MHTypography(weight: .medium, size: 17, lineHeightMultiple: 1.412, letterSpacingPercent: 0.0)
    /// Figma `Headline 2/Regular`
    static let headline2Regular = MHTypography(weight: .regular, size: 17, lineHeightMultiple: 1.412, letterSpacingPercent: 0.0)
    /// Figma `Body 1/Normal -/Bold`
    static let body1NormalBold = MHTypography(weight: .bold, size: 16, lineHeightMultiple: 1.5, letterSpacingPercent: 0.57)
    /// Figma `Body 1/Normal -/Medium`
    static let body1NormalMedium = MHTypography(weight: .medium, size: 16, lineHeightMultiple: 1.5, letterSpacingPercent: 0.57)
    /// Figma `Body 1/Normal -/Regular`
    static let body1NormalRegular = MHTypography(weight: .regular, size: 16, lineHeightMultiple: 1.5, letterSpacingPercent: 0.57)
    /// Figma `Body 1/Reading -/Bold`
    static let body1ReadingBold = MHTypography(weight: .bold, size: 16, lineHeightMultiple: 1.625, letterSpacingPercent: 0.57)
    /// Figma `Body 1/Reading -/Medium`
    static let body1ReadingMedium = MHTypography(weight: .medium, size: 16, lineHeightMultiple: 1.625, letterSpacingPercent: 0.57)
    /// Figma `Body 1/Reading -/Regular`
    static let body1ReadingRegular = MHTypography(weight: .regular, size: 16, lineHeightMultiple: 1.625, letterSpacingPercent: 0.57)
    /// Figma `Body 2/Normal -/Bold`
    static let body2NormalBold = MHTypography(weight: .bold, size: 15, lineHeightMultiple: 1.467, letterSpacingPercent: 0.96)
    /// Figma `Body 2/Normal -/Medium`
    static let body2NormalMedium = MHTypography(weight: .medium, size: 15, lineHeightMultiple: 1.467, letterSpacingPercent: 0.96)
    /// Figma `Body 2/Normal -/Regular`
    static let body2NormalRegular = MHTypography(weight: .regular, size: 15, lineHeightMultiple: 1.467, letterSpacingPercent: 0.96)
    /// Figma `Body 2/Reading -/Bold`
    static let body2ReadingBold = MHTypography(weight: .bold, size: 15, lineHeightMultiple: 1.6, letterSpacingPercent: 0.96)
    /// Figma `Body 2/Reading -/Medium`
    static let body2ReadingMedium = MHTypography(weight: .medium, size: 15, lineHeightMultiple: 1.6, letterSpacingPercent: 0.96)
    /// Figma `Body 2/Reading -/Regular`
    static let body2ReadingRegular = MHTypography(weight: .regular, size: 15, lineHeightMultiple: 1.6, letterSpacingPercent: 0.96)
    /// Figma `Label 1/Normal -/Bold`
    static let label1NormalBold = MHTypography(weight: .bold, size: 14, lineHeightMultiple: 1.429, letterSpacingPercent: 1.45)
    /// Figma `Label 1/Normal -/Medium`
    static let label1NormalMedium = MHTypography(weight: .medium, size: 14, lineHeightMultiple: 1.429, letterSpacingPercent: 1.45)
    /// Figma `Label 1/Normal -/Regular`
    static let label1NormalRegular = MHTypography(weight: .regular, size: 14, lineHeightMultiple: 1.429, letterSpacingPercent: 1.45)
    /// Figma `Label 1/Reading -/Bold`
    static let label1ReadingBold = MHTypography(weight: .bold, size: 14, lineHeightMultiple: 1.571, letterSpacingPercent: 1.45)
    /// Figma `Label 1/Reading -/Medium`
    static let label1ReadingMedium = MHTypography(weight: .medium, size: 14, lineHeightMultiple: 1.571, letterSpacingPercent: 1.45)
    /// Figma `Label 1/Reading -/Regular`
    static let label1ReadingRegular = MHTypography(weight: .regular, size: 14, lineHeightMultiple: 1.571, letterSpacingPercent: 1.45)
    /// Figma `Label 2/Bold`
    static let label2Bold = MHTypography(weight: .bold, size: 13, lineHeightMultiple: 1.385, letterSpacingPercent: 1.94)
    /// Figma `Label 2/Medium`
    static let label2Medium = MHTypography(weight: .medium, size: 13, lineHeightMultiple: 1.385, letterSpacingPercent: 1.94)
    /// Figma `Label 2/Regular`
    static let label2Regular = MHTypography(weight: .regular, size: 13, lineHeightMultiple: 1.385, letterSpacingPercent: 1.94)
    /// Figma `Caption 1/Bold`
    static let caption1Bold = MHTypography(weight: .bold, size: 12, lineHeightMultiple: 1.334, letterSpacingPercent: 2.52)
    /// Figma `Caption 1/Medium`
    static let caption1Medium = MHTypography(weight: .medium, size: 12, lineHeightMultiple: 1.334, letterSpacingPercent: 2.52)
    /// Figma `Caption 1/Regular`
    static let caption1Regular = MHTypography(weight: .regular, size: 12, lineHeightMultiple: 1.334, letterSpacingPercent: 2.52)
    /// Figma `Caption 2/Bold`
    static let caption2Bold = MHTypography(weight: .bold, size: 11, lineHeightMultiple: 1.273, letterSpacingPercent: 3.11)
    /// Figma `Caption 2/Medium`
    static let caption2Medium = MHTypography(weight: .medium, size: 11, lineHeightMultiple: 1.273, letterSpacingPercent: 3.11)
    /// Figma `Caption 2/Regular`
    static let caption2Regular = MHTypography(weight: .regular, size: 11, lineHeightMultiple: 1.273, letterSpacingPercent: 3.11)
}

// MARK: - Preview

// 스케일 한 줄 — 위계명·크기 라벨 + 실제 토큰으로 렌더한 샘플(폰트·크기·자간·행간 반영).
private struct MHTypeRow: View {
    let name: String
    let token: MHTypography
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(name) · \(Int(token.size))pt · LH \(String(format: "%.3g", token.lineHeightMultiple)) · LS \(String(format: "%g", token.letterSpacingPercent))%")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("가나다 Aa 123")
                .mhTypography(token)
                .foregroundStyle(.mhLabelNormal)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// Figma `타이포그래피` 스케일 — 18개 하위 위계(각 Bold 대표). 크기·행간·자간이 토큰에 그대로 반영됨을 확인.
#Preview("MHTypography · 스케일") {
    ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            Group {
                MHTypeRow(name: "Display 1", token: .display1Bold)
                MHTypeRow(name: "Display 2", token: .display2Bold)
                MHTypeRow(name: "Display 3", token: .display3Bold)
                MHTypeRow(name: "Title 1", token: .title1Bold)
                MHTypeRow(name: "Title 2", token: .title2Bold)
                MHTypeRow(name: "Title 3", token: .title3Bold)
                MHTypeRow(name: "Heading 1", token: .heading1Bold)
                MHTypeRow(name: "Heading 2", token: .heading2Bold)
            }
            Group {
                MHTypeRow(name: "Headline 1", token: .headline1Bold)
                MHTypeRow(name: "Headline 2", token: .headline2Bold)
                MHTypeRow(name: "Body 1/Normal", token: .body1NormalBold)
                MHTypeRow(name: "Body 1/Reading", token: .body1ReadingBold)
                MHTypeRow(name: "Body 2/Normal", token: .body2NormalBold)
                MHTypeRow(name: "Body 2/Reading", token: .body2ReadingBold)
                MHTypeRow(name: "Label 1/Normal", token: .label1NormalBold)
                MHTypeRow(name: "Label 1/Reading", token: .label1ReadingBold)
                MHTypeRow(name: "Label 2", token: .label2Bold)
                MHTypeRow(name: "Caption 1", token: .caption1Bold)
                MHTypeRow(name: "Caption 2", token: .caption2Bold)
            }
        }
        .padding()
    }
}

// 굵기 3종(Regular/Medium/Bold) 렌더 확인.
#Preview("MHTypography · 굵기") {
    VStack(alignment: .leading, spacing: 12) {
        Text("Regular 가나다 Aa").mhTypography(.heading1Regular)
        Text("Medium 가나다 Aa").mhTypography(.heading1Medium)
        Text("Bold 가나다 Aa").mhTypography(.heading1Bold)
    }
    .foregroundStyle(.mhLabelNormal)
    .padding()
}
