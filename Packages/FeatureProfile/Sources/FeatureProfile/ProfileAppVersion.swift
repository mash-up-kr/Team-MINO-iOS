import Foundation

/// 서비스 정보 섹션이 보여 주는 **지금 쓰는 앱 버전**.
///
/// 스토어에 올라간 버전이 여러 개가 되면서, 사용자가 자기 기기의 버전을 확인할 자리가 앱 안에
/// 없다는 문제가 생겼다(문의를 받는 쪽도 버전을 물어봐야 한다). 시안에는 없는 행이라 값의
/// 출처와 폴백을 여기 적어 둔다.
enum ProfileAppVersion {
    /// 마케팅 버전(`CFBundleShortVersionString`, 예: `1.0.3`).
    ///
    /// **빌드 번호(`CFBundleVersion`)는 붙이지 않는다.** 같은 스토어 버전 안에서도 계속 올라가는
    /// 값이라, 사용자가 스토어 표기와 대조할 때 오히려 어긋나 보인다.
    static let current = resolve(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString"))

    /// Info.plist 값이 없거나 비면 `-` 로 대신한다 — 빈 문자열이면 오른쪽이 통째로 사라져
    /// 행이 잘린 것처럼 보인다.
    static func resolve(_ raw: Any?) -> String {
        guard let version = raw as? String, !version.isEmpty else { return "-" }
        return version
    }
}
