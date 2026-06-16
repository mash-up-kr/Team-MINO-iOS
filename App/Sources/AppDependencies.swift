import Domain
import Feature

/// 컴포지션 루트(Composition Root).
/// 앱 타깃만이 구체 타입을 알고, 의존성 그래프를 손으로 조립한다.
/// 각 Coordinator 의 deps 프로토콜(`MemberDeps` 등)을 이 한 타입이 준수한다.
struct AppDependencies: MemberDeps {
    let fetchMember: FetchMemberUseCase

    init() {
        // 백엔드 미연결 단계 — 시범용 Stub UseCase 를 주입한다.
        // 실제 API 준비 시 아래 한 줄을 교체한다 (import Networking, Data 추가):
        //   let client = URLSessionHTTPClient(baseURL: URL(string: "<real-base-url>")!)
        //   let repository = MemberRepositoryImpl(client: client)
        //   self.fetchMember = DefaultFetchMemberUseCase(repository: repository)
        self.fetchMember = StubFetchMemberUseCase()
    }
}

/// 백엔드가 붙기 전까지 시범 화면을 동작시키는 임시 Stub. 실제 API 연결 시 제거한다.
struct StubFetchMemberUseCase: FetchMemberUseCase {
    func execute(id: MemberID) async throws -> Member {
        try? await Task.sleep(nanoseconds: 300_000_000)   // 로딩 상태 시범용 지연
        return Member(id: id, name: "김유빈", email: "newbean@mashup.kr")
    }
}
