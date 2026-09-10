import Testing
@testable import FeatureProfile

/// 서비스 정보의 「현재 버전 정보」가 보여 줄 문자열 규칙.
struct ProfileAppVersionTests {
    @Test("Info.plist 의 마케팅 버전을 그대로 보여 준다")
    func showsMarketingVersion() {
        #expect(ProfileAppVersion.resolve("1.0.3") == "1.0.3")
    }

    // 값이 사라지면 오른쪽이 통째로 비어 라벨만 남은 행이 잘린 것처럼 보인다.
    @Test("값이 없거나 비었거나 문자열이 아니면 '-' 로 자리를 지킨다")
    func fallsBackToDash() {
        #expect(ProfileAppVersion.resolve(nil) == "-")
        #expect(ProfileAppVersion.resolve("") == "-")
        #expect(ProfileAppVersion.resolve(3) == "-")
    }
}
