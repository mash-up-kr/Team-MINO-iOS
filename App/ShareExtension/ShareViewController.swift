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
    /// 종료를 한 번만 보낸다. `.dismiss` 를 만드는 경로가 둘(완료 후 자동 닫힘·사용자 닫기)이고,
    /// navigation 은 AsyncStream 이라 둘 사이에 동기 배리어가 없다 — 시트가 걷히는 동안 닫기를
    /// 한 번 더 누르면 completeRequest 가 두 번 불린다(Apple 이 정의하지 않은 동작).
    private var didFinish = false

    /// 조립은 한 번만 한다 — 화면마다 만들면 HTTP 클라이언트가 여러 벌 생긴다.
    private lazy var dependencies = ShareExtensionDependencies()

    override func viewDidLoad() {
        super.viewDidLoad()

        // 세션이 있어야 방 목록·저장이 인증을 통과한다. Store 를 만들기 전에 부른다.
        FirebaseSession.configure()
        // 시트만 그린다 — 루트가 불투명하면 뒤 화면이 가려져 바텀시트로 보이지 않는다
        // (뒤 화면을 실제로 비추는 건 viewDidAppear 의 컨테이너 투명화).
        view.backgroundColor = .clear
        Task { await start() }
    }

    /// 루트 뷰를 직접 만든다 — 컨테이너 투명화를 **뷰가 window 에 붙는 순간**에 걸기 위해서다.
    /// `viewWillAppear` 에서 걸면 등장 애니메이션 첫 프레임에 회색 판이 한 번 비친다.
    override func loadView() {
        view = TransparentRootView()
    }

    private func start() async {
        guard let url = await extractURL() else {
            // 저장할 수 있는 링크가 없으면 우리가 할 수 있는 게 없다 — 조용히 닫는다.
            // cancelRequest 를 쓰지 않는 이유: 넘긴 NSError 를 호스트가 자기 얼럿으로 띄울지,
            // 어떤 문구로 띄울지를 우리가 통제할 수 없다. 사용자에게 보이는 결과는 어차피 둘 다
            // "시트가 닫힌다" 로 같으므로, 남의 화면에 우리 에러가 새는 쪽을 피한다.
            close()
            return
        }

        // Store 를 여기서 만든다 — navigation 을 구독하려면 이 컨트롤러가 필요한데,
        // View 의 makeStore 안에서 self 를 잡으면 옵셔널 처리 때문에 폴백 Store 를 지어내야 한다.
        let store = makeSaveLinkStore(url: url)
        embed(SaveLinkView(makeStore: { store }))
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

    // MARK: - 화면

    private func makeSaveLinkStore(url: URL) -> SaveLinkStore {
        // `savedRoomIDs`(이미 이 링크가 든 방)는 비워 둔다 — 판별하려면 링크가 이미 장소로
        // 추출돼 placeId 가 있어야 하는데(`GET /rooms` 의 showHasPlaceId), 공유 시점의 링크는
        // 아직 추출 전이다. 그래서 시안의 "체크된 채 비활성" 상태는 지금 나타나지 않는다.
        SaveLinkStore(
            SaveLinkState(link: SharedLinkPreview(url: url)),
            reduce: saveLinkReducer(dependencies.makeSaveLinkDependencies()),
            handle: { [weak self] nav in
                switch nav {
                case .dismiss: self?.close()
                }
            }
        )
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
}

private extension URL {
    /// 우리가 저장할 수 있는 링크인지. activation rule 이 웹 URL 만 받으므로 같은 기준을 코드에서도 지킨다.
    var isWebLink: Bool {
        guard let scheme = scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }
}

/// 익스텐션 컨테이너를 투명하게 만들어 **호스트 화면이 시트 뒤로 비치게** 하는 루트 뷰.
///
/// 자기 배경만 `.clear` 로 둬서는 부족하다 — 시스템이 익스텐션 뷰 뒤에 깔아 두는 컨테이너(와
/// window)가 불투명해서 밝은 판이 대신 보인다. 시안의 회색은 "기존 화면 위에 시트가 올라온다"는
/// 표시일 뿐 우리가 그릴 딤이 아니므로, 그 판을 걷어낸다.
///
/// window 진입 시점과 레이아웃마다 다시 거는 이유: 시스템이 등장 애니메이션 도중 컨테이너 배경을
/// 되칠하는 경우가 있어, 한 번만 걸면 올라오는 동안 회색이 스친다.
private final class TransparentRootView: UIView {
    override func didMoveToWindow() {
        super.didMoveToWindow()
        clearContainerBackground()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        clearContainerBackground()
    }

    private func clearContainerBackground() {
        for ancestor in sequence(first: self, next: { $0.superview }) {
            ancestor.backgroundColor = .clear
            ancestor.isOpaque = false
        }
        window?.backgroundColor = .clear
    }
}
