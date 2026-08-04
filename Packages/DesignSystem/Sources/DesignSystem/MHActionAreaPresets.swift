import SwiftUI

//
// Figma `Action Area/Resource/Extra/Preset`. Action Area 의 actions 위(extra 슬롯)에 얹는 콘텐츠.
//
//     MHActionArea(main: .init("결제") { }) {
//         MHActionAreaSummary(label: "결제 금액", value: "12,000원")
//     }
//
// - Custom : 임의 콘텐츠 → 별도 뷰 없이 extra 슬롯에 원하는 뷰를 그대로 넣는다.
// - Summary/Information/Checkbox/Chips : 아래 프리셋.
//
// NOTE: Checkbox 는 `Check Mark`, Chips 는 `Chip/Chip` 이라는 **별도 DS 컴포넌트**를 참조한다.
// 여기서는 프리셋 외형만 인라인 스펙대로 충실히 렌더한다(추후 독립 컴포넌트로 승격 가능).

/// 요약 행: 라벨(좌) ↔ 값(우). Figma `Variant=Summary`
public struct MHActionAreaSummary: View {
    private let label: String
    private let value: String

    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }

    public var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .mhTypography(.body1NormalMedium)
                .foregroundStyle(Color.mhLabelAlternative)
            Spacer(minLength: 8)
            Text(value)
                .mhTypography(.heading2Bold)
                .foregroundStyle(Color.mhLabelStrong)
                .multilineTextAlignment(.trailing)
        }
        .frame(maxWidth: .infinity)
    }
}

/// 정보 블록: 헤딩 + 설명(중앙). Figma `Variant=Information`
public struct MHActionAreaInformation: View {
    private let heading: String
    private let description: String?
    private let icon: MHIcon?

    public init(heading: String, description: String? = nil, icon: MHIcon? = nil) {
        self.heading = heading
        self.description = description
        self.icon = icon
    }

    public var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                if let icon {
                    Image(icon).resizable().frame(width: 22, height: 22)
                        .foregroundStyle(Color.mhLabelStrong)
                }
                Text(heading)
                    .mhTypography(.headline2Bold)
                    .foregroundStyle(Color.mhLabelStrong)
            }
            if let description {
                Text(description)
                    .mhTypography(.label1NormalRegular)
                    .foregroundStyle(Color.mhLabelAlternative)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// 체크 행: 체크 + 라벨(탭 토글). Figma `Variant=Checkbox`
/// NOTE: 정식 상태(미체크/비활성/부분선택)는 별도 `Check Mark` 컴포넌트 소관. 여기선 체크 표시 + 라벨만.
public struct MHActionAreaCheckbox: View {
    private let text: String
    @Binding private var isOn: Bool

    public init(_ text: String, isOn: Binding<Bool>) {
        self.text = text
        self._isOn = isOn
    }

    public var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(alignment: .top, spacing: 4) {
                Image(MHIcon.check)
                    .resizable().frame(width: 24, height: 24)
                    .foregroundStyle(Color.mhLabelNormal)      // NOTE(확인): 체크 색 토큰 미명시 → Label/Normal
                    .opacity(isOn ? 1 : 0.2)
                Text(text)
                    .mhTypography(.body2NormalRegular)
                    .foregroundStyle(Color.mhLabelNormal)
                    .padding(.vertical, 1)
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
    }
}

/// 칩 행. 정식 ``MHChip``(medium·solid) 을 가로로 나열한다. 선택/삭제 등 상태는 후속.
public struct MHActionAreaChips: View {
    private let labels: [String]
    private let onTap: (Int) -> Void

    public init(_ labels: [String], onTap: @escaping (Int) -> Void = { _ in }) {
        self.labels = labels
        self.onTap = onTap
    }

    public var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                MHChip(label, size: .medium) { onTap(index) }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("MHActionArea Extra Presets") {
    struct Host: View {
        @State private var agreed = true
        var body: some View {
            VStack(spacing: 24) {
                MHActionAreaSummary(label: "결제 금액", value: "12,000원")
                MHActionAreaInformation(heading: "안내", description: "필요한 경우 설명을 덧붙입니다.")
                MHActionAreaCheckbox("약관에 동의합니다.", isOn: $agreed)
                MHActionAreaChips(["전체", "최신순", "인기순"])
            }
            .padding()
        }
    }
    return Host()
}
