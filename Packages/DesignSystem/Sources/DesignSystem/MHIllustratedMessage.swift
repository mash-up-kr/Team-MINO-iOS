import SwiftUI

// [Convention] Packages/DesignSystem/README.md — 컴포넌트는 `MH*` 접두사.
// [Convention] 기존 컴포넌트 관행(MHThumbnail.swift·MHLocationCard.swift …) — 파일 1개 = 컴포넌트 1개.
// [Convention] Packages/DesignSystem/Package.swift — DesignSystem 은 의존 패키지가 없다.
//              일러스트 에셋을 `Image` 로 받는 것이 그 조건을 유지한다.

/// ``MHIllustratedMessage`` 의 가로 정렬.
public enum MHIllustratedMessageAlignment: Equatable, Sendable {
    case center
    case leading
}

/// 그림 한 장과 문구로 채우는 화면 골격.
///
/// 일러스트는 **바깥에서 받는다** — 에셋 소유가 호출부 번들에 남아, 에셋이 교체돼도 이 부품은 그대로다.
/// `nil` 이면 일러스트와 그 아래 간격을 통째로 접고 문구만 그린다 — 에셋이 아직 없을 때 빈 칸이
/// 남지 않게 하려는 것이다(``Image/mhAssetIfAvailable(_:bundle:)`` 와 짝).
///
/// **세로 배치는 이 부품이 갖지 않는다** — 남은 영역 중앙에 띄울지 상단에서 시작할지는 감싸는 쪽이
/// 정한다. 배경색도 호출부가 깐다. `illustrationSpacing` 도 같은 이유로 열어 둔 값이다: 일러스트를
/// 화면 어디에 놓느냐에 따라 제목까지의 거리가 달라지므로, 정렬이 아니라 호출부가 정한다.
///
/// ```swift
/// MHIllustratedMessage(illustration: Image("empty"), title: "받은 알림이 없어요")
/// MHIllustratedMessage(
///     illustration: Image("saveError"),
///     title: "확인해주세요",
///     messages: ["현재 한국 내 장소만 지원됩니다.",
///                "사진 속 장소인식은 아직 지원하지 않습니다",
///                "본문에 주소나 장소명을 포함해주세요"],
///     alignment: .leading,
///     illustrationSpacing: 103
/// )
/// ```
public struct MHIllustratedMessage: View {
    private let illustration: Image?
    private let illustrationSize: CGFloat
    private let title: String
    private let messages: [String]
    private let alignment: MHIllustratedMessageAlignment
    private let illustrationSpacing: CGFloat

    /// - Parameters:
    ///   - illustration: 스팟 일러스트. 호출부 번들의 이미지를 그대로 넘긴다. `nil` 이면 생략된다.
    ///   - illustrationSize: 일러스트 한 변의 길이. 시안마다 다르다(알림 빈 상태 173 · 저장 오류 197).
    ///   - title: 제목. 줄 수는 고정하지 않는다 — 길면 줄바꿈된다.
    ///   - messages: 제목 아래 본문. 비우면 제목만 그린다. 줄 수는 고정하지 않는다.
    ///   - alignment: 가로 정렬.
    ///   - illustrationSpacing: 일러스트와 제목 사이 간격.
    public init(
        illustration: Image?,
        illustrationSize: CGFloat = 299,
        title: String,
        messages: [String] = [],
        alignment: MHIllustratedMessageAlignment = .center,
        illustrationSpacing: CGFloat = 32
    ) {
        self.illustration = illustration
        self.illustrationSize = illustrationSize
        self.title = title
        self.messages = messages
        self.alignment = alignment
        self.illustrationSpacing = illustrationSpacing
    }

    public var body: some View {
        // 좌우 인셋은 일러스트에만 주지 않고 VStack 전체에 준다 — leading 정렬에서 제목·본문이
        // 일러스트와 같은 x 에서 시작해야 한다(일러스트만 인셋을 가지면 제목이 화면 끝에 붙는다).
        VStack(alignment: horizontalAlignment, spacing: 0) {
            if let illustration {
                illustration
                    .resizable()
                    .scaledToFit()
                    .frame(width: illustrationSize, height: illustrationSize)
                    .accessibilityHidden(true)
            }

            Text(title)
                .mhTypography(.headline1Bold)
                .foregroundStyle(.mhLabelStrong)
                .multilineTextAlignment(textAlignment)
                // 일러스트가 없으면 그 아래 간격도 함께 사라져야 한다 — 안 그러면 문구 위에
                // 근거 없는 여백만 남는다.
                .padding(.top, illustration == nil ? 0 : illustrationSpacing)

            if !messages.isEmpty {
                VStack(alignment: horizontalAlignment, spacing: 12) {
                    ForEach(Array(messages.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .mhTypography(.label1NormalRegular)
                            .foregroundStyle(.mhLabelAlternative)
                            .multilineTextAlignment(textAlignment)
                    }
                }
                .padding(.top, 24)
            }
        }
        .padding(.horizontal, 38)
    }

    // switch(삼항 대신) — 정렬 케이스가 늘 때 한쪽만 고치는 실수를 컴파일 에러로 막는다.
    private var horizontalAlignment: HorizontalAlignment {
        switch alignment {
        case .center: .center
        case .leading: .leading
        }
    }

    private var textAlignment: TextAlignment {
        switch alignment {
        case .center: .center
        case .leading: .leading
        }
    }
}

#Preview("MHIllustratedMessage · Light") {
    VStack(spacing: 40) {
        MHIllustratedMessage(
            illustration: Image(systemName: "bell.slash"),
            title: "받은 알림이 없어요"
        )
        MHIllustratedMessage(
            illustration: Image(systemName: "exclamationmark.triangle"),
            title: "확인해주세요",
            messages: [
                "현재 한국 내 장소만 지원됩니다.",
                "사진 속 장소인식은 아직 지원하지 않습니다",
                "본문에 주소나 장소명을 포함해주세요"
            ],
            alignment: .leading,
            illustrationSpacing: 103
        )
    }
    .padding()
    .background(Color.mhBackgroundNormalNormal)
    .preferredColorScheme(.light)
}

#Preview("MHIllustratedMessage · Dark") {
    VStack(spacing: 40) {
        MHIllustratedMessage(
            illustration: Image(systemName: "bell.slash"),
            title: "받은 알림이 없어요"
        )
        MHIllustratedMessage(
            illustration: Image(systemName: "exclamationmark.triangle"),
            title: "확인해주세요",
            messages: [
                "현재 한국 내 장소만 지원됩니다.",
                "사진 속 장소인식은 아직 지원하지 않습니다",
                "본문에 주소나 장소명을 포함해주세요"
            ],
            alignment: .leading,
            illustrationSpacing: 103
        )
    }
    .padding()
    .background(Color.mhBackgroundNormalNormal)
    .preferredColorScheme(.dark)
}
