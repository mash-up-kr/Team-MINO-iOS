import Foundation

/// 핀 하나를 단독 조회했을 때 얻는 것 — 목록에는 실리지 않는 출처 링크가 함께 온다.
///
/// `Pin.sourceURL: URL?` 로 합치지 않는다. 그러면 nil 이 "목록 응답이라 안 실렸다"와
/// "출처가 없는 핀이다" 두 뜻을 갖게 되고, 구별은 주석으로만 남는다.
/// 서버 스키마도 `Pin` 과 `PinDetail` 을 나눠 두었으므로 도메인도 그 구분을 지킨다.
public struct PinDetail: Equatable, Sendable {
    public let pin: Pin
    /// 이 장소가 어디서 왔는지(예: 인스타그램 게시물). 출처가 없는 핀은 nil.
    public let sourceURL: URL?

    public init(pin: Pin, sourceURL: URL?) {
        self.pin = pin
        self.sourceURL = sourceURL
    }
}
