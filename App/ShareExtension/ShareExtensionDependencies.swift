import Core
import Data
import Domain
import Foundation
import Networking
import SavePostUI
import ShareExtensionUI

/// 익스텐션의 Composition Root. 본앱 `AppDependencies` 와 같은 역할이되 익스텐션이 쓰는 것만 조립한다
/// — 별도 프로세스라 본앱이 만든 그래프를 물려받을 수 없고, 네트워크 호출도 여기서 직접 나간다.
struct ShareExtensionDependencies {
    private let fetchRooms: FetchRoomsUseCase
    private let saveLink: SaveLinkToRoomsUseCase

    init() {
        // 인증 토큰은 클라이언트가 요청마다 붙인다. 익스텐션의 세션은 Keychain 공유로 본앱과
        // 같은 것을 보므로(`FirebaseSession.configure`), 여기서는 본앱과 같은 provider 를 쓴다.
        let client = URLSessionHTTPClient(
            baseURL: APIEnvironment.baseURL,
            tokenProvider: FirebaseAuthTokenProvider()
        )
        self.fetchRooms = DefaultFetchRoomsUseCase(repository: RoomRepositoryImpl(client: client))
        self.saveLink = DefaultSaveLinkToRoomsUseCase(repository: SaveLinkRepositoryImpl(client: client))
    }

    /// UseCase → 화면이 받는 클로저로 옮긴다. `ShareExtensionUI` 는 공용 UI 레이어라
    /// `Domain` 을 알지 않으므로, 이 변환이 조립부의 몫이다.
    func makeSaveLinkDependencies() -> SaveLinkDependencies {
        SaveLinkDependencies(
            loadRooms: { try await fetchRooms.execute().map(SavePostRoom.init(_:)) },
            save: { url, roomIDs in try await saveLink.execute(url: url, roomIDs: roomIDs) },
            // 완료 스낵바를 읽을 시간. 이만큼 지나면 익스텐션이 스스로 닫힌다.
            holdCompletion: { try? await Task.sleep(for: .seconds(1.2)) }
        )
    }
}
