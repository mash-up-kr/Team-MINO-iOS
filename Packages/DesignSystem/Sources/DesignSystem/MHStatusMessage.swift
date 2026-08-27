import SwiftUI

// [Convention] Packages/DesignSystem/README.md — 컴포넌트는 `MH*` 접두사.
// [Convention] 기존 컴포넌트 관행(MHThumbnail.swift·MHLocationCard.swift …) — 파일 1개 = 컴포넌트 1개.
// [Convention] .claude/docs/mvi-coordinator-di.md:60 — 상태를 들지 않고 디자인 토큰만으로 그려지므로
//              `*UI` 가 아니라 DesignSystem 에 둔다.

/// ``MHStatusMessage`` 가 알리는 상황.
///
/// 시안이 오면 진행 중과 실패는 생김새가 갈릴 가능성이 크다(스피너 vs 아이콘+버튼). 그때
/// `body` 만 갈라지고 호출부는 그대로이도록, 지금부터 케이스로 나눠 둔다.
public enum MHStatusMessageKind {
    /// 아직 진행 중이라 보여줄 것이 없다.
    case progress
    /// 실패해서 다시 시도할 수 있다.
    ///
    /// - Parameters:
    ///   - retryTitle: 다시 시도 자리의 문구. 상황마다 카피가 다를 수 있어 기본값을 두지 않는다.
    ///   - onRetry: 다시 시도 동작.
    case failure(retryTitle: String, onRetry: () -> Void)
}

/// 화면이 아직 내용을 보여줄 수 없을 때 쓰는 안내 부품. 조회 중 · 조회 실패 · 이어 붙이기 실패
/// 세 상황이 이 골격을 나눠 쓴다.
///
/// **점유 범위는 이 부품이 정하지 않는다** — 화면 전체를 덮을지(조회 실패) 목록 끝 한 줄로 앉을지
/// (이어 붙이기 실패)는 감싸는 쪽이 프레임으로 정한다. 배경색과 `accessibilityIdentifier` 도
/// 호출 화면이 붙인다.
///
/// ```swift
/// MHStatusMessage(message: "알림을 불러오는 중이에요")
/// MHStatusMessage(message: "알림을 불러오지 못했어요",
///                 kind: .failure(retryTitle: "다시 시도") { store.send(.retry) })
/// ```
// TODO: 시안 나오면 수정 — 조회 중·조회 실패·이어 붙이기 실패 셋 다 figma 프레임이 없다(디자이너
//       요청 대상). 지금은 문구 한 줄 + 다시 시도 자리로만 둔다.
public struct MHStatusMessage: View {
    private let message: String
    private let kind: MHStatusMessageKind

    /// - Parameters:
    ///   - message: 지금 상황을 알리는 한 줄.
    ///   - kind: 진행 중인지 실패인지.
    public init(message: String, kind: MHStatusMessageKind = .progress) {
        self.message = message
        self.kind = kind
    }

    public var body: some View {
        VStack(spacing: 12) {
            Text(message)
                .mhTypography(.label1NormalRegular)
                .foregroundStyle(.mhLabelAlternative)
            if case let .failure(retryTitle, onRetry) = kind {
                MHTextButton(retryTitle, variant: .primary, action: onRetry)
            }
        }
    }
}

#Preview("MHStatusMessage · Light") {
    VStack(spacing: 32) {
        MHStatusMessage(message: "알림을 불러오는 중이에요")
        MHStatusMessage(message: "알림을 불러오지 못했어요",
                         kind: .failure(retryTitle: "다시 시도") {})
    }
    .padding()
    .background(Color.mhBackgroundNormalNormal)
    .preferredColorScheme(.light)
}

#Preview("MHStatusMessage · Dark") {
    VStack(spacing: 32) {
        MHStatusMessage(message: "알림을 불러오는 중이에요")
        MHStatusMessage(message: "알림을 불러오지 못했어요",
                         kind: .failure(retryTitle: "다시 시도") {})
    }
    .padding()
    .background(Color.mhBackgroundNormalNormal)
    .preferredColorScheme(.dark)
}
