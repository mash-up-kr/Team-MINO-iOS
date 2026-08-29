/// 본앱과 공유 익스텐션이 함께 여는 Keychain 그룹.
///
/// 익스텐션은 번들 ID 가 달라(`…teamMino` vs `…teamMino.ShareExtension`) 기본 access group 이
/// 서로 다르다. Firebase Auth 가 세션을 Keychain 에 두므로, 이 그룹을 지정하지 않으면 익스텐션의
/// `currentUser` 가 **본앱에서 멀쩡히 로그인돼 있어도 nil** 이다.
///
/// > ⚠️ 앞의 팀 ID 는 `App.entitlements`·`ShareExtension.entitlements` 의
/// > `$(AppIdentifierPrefix)` 가 치환되는 값과 **글자 그대로 같아야** 한다. entitlements 는
/// > 빌드가 치환하지만 여기는 그러지 않아서, 팀을 옮기면 이 문자열만 조용히 남는다.
/// > 어긋나면 크래시가 아니라 "세션이 안 보인다"로만 드러난다.
public enum SharedKeychain {
    public static let accessGroup = "D2DRA3F792.com.mashup.teamMino.shared"
}
