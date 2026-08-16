import Foundation

/// 온보딩 튜토리얼이 Share Extension 을 연습용으로 부를 때 쓰는 약속.
///
/// 튜토리얼이 이 URL 을 공유하면 익스텐션은 저장하지 않고 바로 닫는다
/// (축하 화면은 본앱의 튜토리얼 완료 단계가 그린다).
///
/// 본앱(FeatureOnboarding)과 익스텐션이 같은 값을 봐야 해서 둘 다 링크하는 Core 에 둔다.
public enum TutorialShare {
    /// 튜토리얼 전용 센티넬 URL.
    ///
    /// - 실제로 존재할 수 없는 경로를 쓴다. 사용자가 우연히 이 페이지를 열어 공유하면
    ///   저장 화면 대신 아무 일도 안 일어난 것처럼 닫히기 때문이다
    ///   (`gguk.org` 는 응답하는 도메인이라 `/tutorial` 같은 평범한 경로는 위험하다).
    /// - AASA 의 `paths` 는 `/r/*` 로 좁혀야 한다. `*` 로 넓게 걸면 같은 호스트인 이 URL 도
    ///   앱을 열게 되고, 딥링크 파서는 이걸 목적지로 읽지 못해 앱이 뜬 채 아무 일도 일어나지 않는다.
    /// - `https` 여야 한다. 익스텐션의 activation rule 이
    ///   `NSExtensionActivationSupportsWebURLWithMaxCount` 라 커스텀 스킴은 공유시트에 뜨지 않는다.
    public static let sentinelURL = URL(string: "https://gguk.org/__tutorial-practice__")!
}
