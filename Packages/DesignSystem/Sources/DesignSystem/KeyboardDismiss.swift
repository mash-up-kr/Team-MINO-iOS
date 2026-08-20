import SwiftUI
import UIKit

public extension View {
    /// 입력 영역 **바깥**을 탭하면 키보드를 내린다. 자유 입력이 있는 화면 루트에 붙인다.
    ///
    /// 화면 전체를 탭 대상으로 만들지만(`contentShape`), 버튼·입력 필드 같은 자식 컨트롤이 탭을
    /// 먼저 가져가므로 그것들의 동작은 그대로다 — 아무것도 없는 여백을 탭했을 때만 발동한다.
    ///
    /// > 멀티라인 입력(``MHTextArea``)은 리턴키가 개행으로 소비돼 리턴키로 못 닫는다. 이 modifier 와
    /// > 스크롤 해제(`.scrollDismissesKeyboard`), ``MHTextArea`` 내부 키보드 툴바가 함께 탈출로가 된다.
    func mhDismissKeyboardOnTap() -> some View {
        contentShape(Rectangle())
            .onTapGesture { mhResignFirstResponder() }
    }
}

/// 현재 first responder 에서 포커스를 뗀다. 어떤 필드가 포커스인지 몰라도 되도록 responder chain 에 던진다.
@MainActor
func mhResignFirstResponder() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
