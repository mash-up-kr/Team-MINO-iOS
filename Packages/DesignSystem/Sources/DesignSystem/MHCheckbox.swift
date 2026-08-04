import SwiftUI

// MARK: - Checkbox

/// 체크박스 크기. Figma `size` = Normal(18) / Small(16).
public enum MHCheckboxSize: Sendable {
    case normal, small
    var box: CGFloat { self == .normal ? 18 : 16 }
    var icon: CGFloat { self == .normal ? 16 : 14 }   // 체크 아이콘(박스보다 살짝 작음)
}

/// 체크박스 상태. Figma `state` = Unchecked / Checked / Indeterminate.
public enum MHCheckboxState: Sendable { case unchecked, checked, indeterminate }

/// 네모 체크박스. Figma `Checkbox/Resource/Control`(node 16215:34459).
///
/// `unchecked` 는 `Line/Normal/Normal` 테두리의 빈 박스, `checked`·`indeterminate` 는 `Primary/Normal`(검정)
/// 채움에 흰 체크(✓)/가로선(−)을 얹는다. `action` 을 주면 눌러지며, 눌림 시 둘레에 옅은 halo 가 뜬다.
/// 비활성(`.disabled`)은 전체를 흐리게(opacity 0.43) 하고 상호작용을 끈다.
///
/// ```swift
/// MHCheckbox(isOn: $agree)                                  // 2-상태(탭 토글)
/// MHCheckbox(state: .indeterminate, size: .small) { toggle() }   // 3-상태(미결정 포함)
/// ```
public struct MHCheckbox: View {
    private let state: MHCheckboxState
    private let size: MHCheckboxSize
    private let action: (() -> Void)?

    @Environment(\.isEnabled) private var isEnabled

    public init(state: MHCheckboxState, size: MHCheckboxSize = .normal, action: (() -> Void)? = nil) {
        self.state = state
        self.size = size
        self.action = action
    }

    /// 2-상태 편의(탭하면 토글). 미결정이 필요하면 `state:` 이니셜라이저를 쓴다.
    public init(isOn: Binding<Bool>, size: MHCheckboxSize = .normal) {
        self.state = isOn.wrappedValue ? .checked : .unchecked
        self.size = size
        self.action = { isOn.wrappedValue.toggle() }
    }

    public var body: some View {
        Group {
            if let action {
                Button(action: action) { box }.buttonStyle(MHCheckboxStyle(size: size))
            } else {
                box
            }
        }
        .opacity(isEnabled ? 1 : 0.43)
    }

    private var filled: Bool { state != .unchecked }

    @ViewBuilder private var box: some View {
        let shape = RoundedRectangle(cornerRadius: 5)
        ZStack {
            if filled {
                shape.fill(Color.mhPrimaryNormal)       // 체크/미결정: 검정 채움
                mark
            } else {
                shape.strokeBorder(.mhLineNormalNormal, lineWidth: 1.5)   // 빈 박스 테두리
            }
        }
        .frame(width: size.box, height: size.box)
    }

    // 흰 표식: checked=체크 아이콘, indeterminate=가로선(우리 세트에 lineHorizontal 없어 바로 그림).
    @ViewBuilder private var mark: some View {
        switch state {
        case .unchecked:
            EmptyView()
        case .checked:
            Image(MHIcon.check)
                .resizable().scaledToFit()
                .frame(width: size.icon, height: size.icon)
                .foregroundStyle(.mhStaticWhite)
        case .indeterminate:
            Capsule()
                .fill(Color.mhStaticWhite)
                .frame(width: size.icon * 0.625, height: 1.5)   // minus 근사
        }
    }
}

// MARK: - ButtonStyle (press halo)

// Figma `Interaction`: 눌림 시 박스보다 4px 큰 둥근 halo(Label/Normal). 정확한 불투명도는 미실측 → 0.09 근사.
struct MHCheckboxStyle: ButtonStyle {
    let size: MHCheckboxSize
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                if configuration.isPressed {
                    RoundedRectangle(cornerRadius: (size.box + 8) / 2)
                        .fill(Color.mhLabelNormal.opacity(0.09))
                        .frame(width: size.box + 8, height: size.box + 8)
                }
            }
    }
}

#Preview("MHCheckbox") {
    VStack(spacing: 20) {
        ForEach([MHCheckboxSize.normal, .small], id: \.box) { size in
            HStack(spacing: 20) {
                MHCheckbox(state: .unchecked, size: size) { }
                MHCheckbox(state: .checked, size: size) { }
                MHCheckbox(state: .indeterminate, size: size) { }
                MHCheckbox(state: .checked, size: size) { }.disabled(true)
            }
        }
    }
    .padding()
}
