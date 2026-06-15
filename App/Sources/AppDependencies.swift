import UIKit
import Networking
import Domain
import Data
import Feature

/// 컴포지션 루트(Composition Root).
/// 앱 타깃만이 구체 타입(Data/Networking 구현)을 알고, 의존성 그래프를 손으로 조립한다.
@MainActor
final class AppDependencies {
    private let fetchMemberUseCase: FetchMemberUseCase

    init() {
        let baseURL = URL(string: "https://api.example.com")!
        let httpClient: HTTPClient = URLSessionHTTPClient(baseURL: baseURL)
        let memberRepository: MemberRepository = MemberRepositoryImpl(client: httpClient)
        self.fetchMemberUseCase = DefaultFetchMemberUseCase(repository: memberRepository)
    }

    func makeRootViewController() -> UIViewController {
        MemberViewController(useCase: fetchMemberUseCase, memberID: MemberID("1"))
    }
}
