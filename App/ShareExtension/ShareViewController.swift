import Core
import ShareExtensionUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// 공유시트에서 "꾹"을 눌렀을 때 뜨는 익스텐션의 진입점.
///
/// `SLComposeServiceViewController` 를 쓰지 않는다 — 시안이 커스텀 바텀시트라
/// 그 컨트롤러가 강제하는 텍스트 입력 폼 레이아웃을 벗어날 수 없다.
///
/// 익스텐션에는 Coordinator 가 없다. Store 를 만들고 `observeNavigation` 으로
/// 화면 전환 의도를 받아 자기를 끝내는 것까지 이 컨트롤러가 맡는다.
final class ShareViewController: UIViewController {
    /// 공유로 들어온 입력의 종류.
    private enum ShareEntry {
        /// 사용자가 실제로 저장하려는 링크.
        case link(URL)
        /// 온보딩 튜토리얼이 연습용으로 띄운 것. 저장하지 않고 바로 닫는다.
        case tutorial
    }

    /// 종료를 한 번만 보낸다. `.dismiss` 를 만드는 경로가 둘(완료 후 자동 닫힘·사용자 닫기)이고,
    /// navigation 은 AsyncStream 이라 둘 사이에 동기 배리어가 없다 — 시트가 걷히는 동안 닫기를
    /// 한 번 더 누르면 completeRequest 가 두 번 불린다(Apple 이 정의하지 않은 동작).
    private var didFinish = false

    override func viewDidLoad() {
        super.viewDidLoad()
        // 딤과 시트를 직접 그린다 — 루트가 불투명하면 뒤 화면이 가려져 바텀시트로 보이지 않는다.
        view.backgroundColor = .clear
        Task { await start() }
    }

    private func start() async {
        guard let url = await extractURL() else {
            // URL 이 없으면 우리가 할 수 있는 게 없다. 호스트 앱에 취소로 알린다.
            cancel(with: .noURL)
            return
        }

        switch classify(url) {
        case .link(let url):
            // Store 를 여기서 만든다 — navigation 을 구독하려면 이 컨트롤러가 필요한데,
            // View 의 makeStore 안에서 self 를 잡으면 옵셔널 처리 때문에 폴백 Store 를 지어내야 한다.
            let store = makeSaveLinkStore(url: url)
            embed(SaveLinkView(makeStore: { store }))
        case .tutorial:
            // 튜토리얼은 연습이라 저장하지 않는다. 축하는 본앱의 튜토리얼 완료 단계가 그리므로
            // 여기서 화면을 띄우면 같은 말이 두 번 나온다 — 조용히 닫아 본앱으로 넘긴다.
            close()
        }
    }

    // MARK: - 입력 해석

    private func extractURL() async -> URL? {
        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
            .flatMap { $0.attachments ?? [] }

        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            // public.file-url 이 public.url 에 conform 해서 위 검사만으로는 파일 URL 도 통과한다.
            // 웹 링크와 파일을 함께 첨부하는 앱에서 파일 쪽이 먼저 오면 file:/// 경로를 저장하게 된다.
            if let url = await loadURL(from: provider), url.isWebLink { return url }
        }
        return nil
    }

    /// `loadItem` 의 async 오버로드는 `NSSecureCoding`(비-Sendable)을 격리 경계 너머로 돌려주려 해
    /// Swift 6 에서 막힌다. 콜백 판을 쓰고 클로저 안에서 `URL` 로 좁혀 continuation 에만 싣는다.
    private func loadURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { (continuation: CheckedContinuation<URL?, Never>) in
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                continuation.resume(returning: item as? URL)
            }
        }
    }

    /// 튜토리얼 전용 센티넬 URL 인지 가른다. 실제 처리는 호출부의 `case .tutorial` 이 한다.
    ///
    /// 센티넬 URL 하나만 보므로, 사용자가 이 주소를 다른 곳에서 공유해도 튜토리얼로 친다.
    /// 본앱이 세우는 "튜토리얼 진행 중" 플래그를 함께 보면 막히는데, 그건 프로세스 간
    /// 공유 저장소(App Group)가 필요해 미뤘다 — 튜토리얼 연동 PR 에서 함께 정한다.
    /// (그 사이 오인을 줄이려고 센티넬 경로를 실재할 수 없는 값으로 둔다 — `TutorialShare` 참조)
    private func classify(_ url: URL) -> ShareEntry {
        url == TutorialShare.sentinelURL ? .tutorial : .link(url)
    }

    // MARK: - 화면

    private func makeSaveLinkStore(url: URL) -> SaveLinkStore {
        let store = SaveLinkStore(
            // TODO: 방 목록 API 가 붙으면 조회 결과로 바꾼다.
            SaveLinkState(link: SharedLinkPreview(url: url), rooms: SharedRoom.samples),
            reduce: saveLinkReducer(.stub)   // TODO: 저장 API 가 붙으면 UseCase 주입으로 교체
        )
        store.observeNavigation { [weak self] nav in
            switch nav {
            case .dismiss: self?.close()
            }
        }
        return store
    }

    private func embed(_ content: some View) {
        let host = UIHostingController(rootView: content)
        host.view.backgroundColor = .clear
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        host.didMove(toParent: self)
    }

    private func close() {
        guard !didFinish else { return }
        didFinish = true
        extensionContext?.completeRequest(returningItems: nil)
    }

    private func cancel(with error: ShareExtensionError) {
        guard !didFinish else { return }
        didFinish = true
        extensionContext?.cancelRequest(withError: error)
    }
}

private enum ShareExtensionError: Error {
    case noURL
}

private extension URL {
    /// 우리가 저장할 수 있는 링크인지. activation rule 이 웹 URL 만 받으므로 같은 기준을 코드에서도 지킨다.
    var isWebLink: Bool {
        guard let scheme = scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }
}
