import Foundation

/// API 서버 주소. 본앱과 익스텐션이 **각자** HTTP 클라이언트를 조립하므로 둘 다 여기를 본다.
///
/// 서버가 하나라 분기를 두지 않는다. 로컬·스테이징이 생기면 그때 환경 분기를 만든다.
public enum APIEnvironment {
    public static let baseURL = URL(string: "https://api.gguk.org")!
}
