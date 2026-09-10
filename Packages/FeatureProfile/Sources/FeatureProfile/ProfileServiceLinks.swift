import Foundation

/// 서비스 정보 섹션이 여는 바깥 주소.
enum ProfileServiceLinks {
    /// 서비스 이용약관·개인정보 처리방침을 담은 노션 문서(FR-011).
    static let terms = URL(string: "https://app.notion.com/p/3bdbee7f599680028b69f036fd989613?source=copy_link")!

    /// App Store 리뷰 작성 페이지(FR-012).
    ///
    /// `?action=write-review` 를 붙이면 스토어 페이지가 리뷰 작성 시트를 편 채로 열린다.
    private static let appStoreID = "6806306129"

    static let appReview = URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")!
}
