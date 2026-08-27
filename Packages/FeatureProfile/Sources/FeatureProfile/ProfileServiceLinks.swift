import Foundation

/// 서비스 정보 섹션이 여는 바깥 주소.
enum ProfileServiceLinks {
    /// 서비스 이용약관·개인정보 처리방침을 담은 노션 문서(FR-011).
    static let terms = URL(string: "https://app.notion.com/p/3bdbee7f599680028b69f036fd989613?source=copy_link")!

    /// App Store 리뷰 작성 페이지(FR-012).
    ///
    /// **앱 ID 가 아직 없다** — 앱이 App Store Connect 에 올라가면 아래 상수만 채우면 된다.
    /// 값이 없는 동안 `appReview` 는 `nil` 이고, 화면은 그 행을 눌러도 아무 일도 하지 않는다.
    private static let appStoreID: String? = nil

    static var appReview: URL? {
        appStoreID.flatMap { URL(string: "https://apps.apple.com/app/id\($0)?action=write-review") }
    }
}
