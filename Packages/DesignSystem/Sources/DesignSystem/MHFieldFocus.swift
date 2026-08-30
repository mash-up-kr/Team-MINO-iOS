import SwiftUI

/// 지금 포커스된 입력 필드를 화면 쪽으로 알린다. 값은 그 필드의 `identifier`.
///
/// 평범한 `ScrollView` 는 포커스된 필드로 **자동 스크롤하지 않는다** — 그건 `List`/`Form` 만의 동작이다.
/// 그래서 폼 화면이 직접 스크롤해야 하는데, 그러려면 어느 필드가 포커스인지 알아야 한다.
/// ``MHTextField``·``MHTextArea`` 가 이 값을 올려 보내고, 화면은 `onPreferenceChange` 로 받는다.
///
/// > `identifier` 를 주지 않은 필드는 알릴 이름이 없어 포함되지 않는다.
public struct MHFocusedFieldKey: PreferenceKey {
    public static let defaultValue: String? = nil

    public static func reduce(value: inout String?, nextValue: () -> String?) {
        value = value ?? nextValue()
    }
}

extension View {
    /// 포커스 상태를 ``MHFocusedFieldKey`` 로 올려 보낸다. 입력 컴포넌트 내부에서만 쓴다.
    func mhReportFieldFocus(_ identifier: String?, isFocused: Bool) -> some View {
        preference(key: MHFocusedFieldKey.self, value: isFocused ? identifier : nil)
    }
}
