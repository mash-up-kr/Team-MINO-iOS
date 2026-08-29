import Foundation

/// 핀 하나를 단독 조회하는 저장소 추상 — 목록에 실리지 않는 출처 링크를 얻기 위한 경로다.
/// 구현체(Data 계층)가 API/DB/Mock 중 무엇을 쓰는지 Domain 은 알지 못한다.
public protocol PinDetailRepository: Sendable {
    func pinDetail(id: PinID) async throws -> PinDetail
}
