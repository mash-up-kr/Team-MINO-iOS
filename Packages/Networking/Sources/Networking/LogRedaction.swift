import Foundation

/// 로그에 남길 값에서 민감한 부분을 가린다.
///
/// `OSLogger` 는 메시지·메타데이터를 `privacy: .public` 으로 찍는다 — 통합 로그에 **평문으로
/// 영구 기록**되고 sysdiagnose·Console 로 추출된다. 그리고 릴리즈 최소 레벨이 `.warning` 이라
/// 실패 경로의 로그는 실제로 기기에 남는다. 릴리즈에 남기는 값은 "장애를 조사할 수 있을 만큼"
/// 이면서 "그 자체로 권한을 주지 않아야" 한다.
///
/// 가장 위험한 건 **경로에 들어간 식별자**다. 초대 코드가 `/api/v1/invitations/{code}` 로
/// 경로에 실리는데, 이 값 하나면 누구나 그 방에 입장할 수 있다. 쿼리만 떼는 것으로는 부족하다.
///
/// 각 함수는 빌드 구성을 **기본값으로만** 받는다 — 그래야 릴리즈 동작도 테스트로 고정된다.
enum LogRedaction {
    static let isDebugBuild: Bool = {
        #if DEBUG
        true
        #else
        false
        #endif
    }()

    /// DEBUG 는 전체 URL, 릴리즈는 식별자를 가린 경로만.
    static func url(_ url: URL?, full: Bool = isDebugBuild) -> String {
        guard let url else { return "-" }
        return full ? url.absoluteString : maskIdentifiers(in: url.path())
    }

    static func path(_ path: String, masked: Bool = !isDebugBuild) -> String {
        masked ? maskIdentifiers(in: path) : path
    }

    /// 응답 본문. DEBUG 는 앞부분을 그대로, 릴리즈는 **크기만** 남긴다.
    ///
    /// 서버 에러 본문에는 요청 에코·이메일·방 이름이 실릴 수 있어 릴리즈에 남기면 안 되는데,
    /// "본문이 있었는지 / 얼마나 컸는지" 는 계약 위반을 판단하는 데 여전히 쓸모가 있다.
    static func body(_ data: Data, includePreview: Bool = isDebugBuild) -> [String: String] {
        includePreview
            ? ["preview": String(decoding: data.prefix(200), as: UTF8.self)]
            : ["bodyBytes": String(data.count)]
    }

    /// 경로에서 식별자로 보이는 세그먼트를 `***` 로 바꾼다.
    static func maskIdentifiers(in path: String) -> String {
        path
            .split(separator: "/", omittingEmptySubsequences: false)
            .map { isIdentifier($0) ? "***" : $0 }
            .joined(separator: "/")
    }

    /// UUID·연속 숫자·초대 코드처럼 "값" 인 세그먼트인가.
    /// `api`·`v1`·`rooms` 같은 고정 세그먼트는 남겨야 어느 API 인지 알 수 있다.
    ///
    /// ⚠️ 휴리스틱이라 **경로 이름이 우연히 조건을 만족하면 그것도 가려진다**
    /// (`oauth2`·`v2beta` 처럼 6자 이상이면서 숫자를 포함하는 이름). 그러면 릴리즈
    /// 로그에서 어느 API 인지 알 수 없게 되므로, 그런 이름이 생기면 예외 목록이 필요하다.
    private static func isIdentifier(_ segment: Substring) -> Bool {
        if segment.isEmpty { return false }
        if UUID(uuidString: String(segment)) != nil { return true }
        if segment.allSatisfy(\.isNumber) { return true }
        // 초대 코드(스펙상 최대 16자 영숫자)처럼 숫자가 섞인 긴 토큰.
        // `v1` 같은 짧은 고정 세그먼트를 살리려고 길이 하한을 둔다.
        return segment.count >= 6
            && segment.contains(where: \.isNumber)
            && segment.allSatisfy { $0.isLetter || $0.isNumber }
    }
}
