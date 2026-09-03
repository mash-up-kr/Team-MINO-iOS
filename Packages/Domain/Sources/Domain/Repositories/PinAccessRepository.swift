import Foundation

/// 장소를 **열어 봤다**는 사실을 남기는 자리.
///
/// 조회(`PinRepository`)와 나눠 둔 이유는 방향이 반대라서다 — 이쪽은 읽기가 없고 기록만 한다.
/// 서버는 이 로그를 홈 카드 덱의 **묵힘 계산**(꾹 Pick 순위: 최근 확인한 장소는 뒤로 밀린다)과
/// **클릭수 집계**(`친구들이 많이 본 곳` 라벨)의 원천으로 쓴다.
public protocol PinAccessRepository: Sendable {
    func recordAccess(pinID: PinID) async throws
}
