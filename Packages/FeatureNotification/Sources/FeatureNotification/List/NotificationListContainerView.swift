import DesignSystem
import Domain
import MVI
import SwiftUI

/// `NotificationListStore` 를 소비해 화면 상태 5종(로딩·목록·빈 상태·전체 실패·추가 로드 실패)을
/// 분기하는 컨테이너. MARKUP 완성본 ``NotificationListContentView`` (수정 안 함)를 감싸 실데이터를
/// 주입한다 — 목록은 그 뷰가, 빈 상태는 PR3 ``MHIllustratedMessage``, 로딩·전체 실패·추가 로드 실패는
/// PR3 ``MHStatusMessage`` 가 맡는다.
///
/// [Convention] .claude/docs/mvi-coordinator-di.md §5 — `XxxHomeContentView` 는 `store.state` 를
/// 읽어 그리고, 최초 로드는 이 뷰의 `.task` 에서 트리거한다(``ArchiveShellView`` 선례).
struct NotificationListContainerView: View {
    let store: NotificationListStore

    var body: some View {
        // `.task` 를 `content`(phase 별로 다른 분기를 내는 @ViewBuilder) 에 직접 걸면 phase 가
        // 바뀔 때마다 그 분기의 정체성도 함께 바뀌어 task 가 재시작된다. 항상 동일한 정체성을
        // 유지하는 바깥 컨테이너에 걸어야 phase 전환과 무관하게 최초 1회만 실행된다.
        ZStack { content }
            .task {
                guard store.state.phase == .loading, store.state.items.isEmpty else { return }
                store.send(.load)
            }
    }

    // 목록(.loaded, 비어있지 않음) 상태는 헤더를 ``NotificationListContentView`` 자신이 그린다.
    // 그 외 4종은 여기서 헤더를 함께 그려 화면 상단 구성을 일관되게 유지한다.
    @ViewBuilder
    private var content: some View {
        switch store.state.phase {
        case .loading:
            withHeader { centeredStatus(message: "알림을 불러오는 중이에요") }
                .accessibilityIdentifier("Notification.loading")

        case .failed:
            withHeader {
                centeredStatus(
                    message: "알림을 불러오지 못했어요",
                    kind: .failure(retryTitle: "다시 시도") { store.send(.load) }
                )
            }
            .accessibilityIdentifier("Notification.failed")

        case .loaded where store.state.items.isEmpty && store.state.nextRequest == nil:
            // UX-001 — 로딩 중엔 빈 상태 문구를 보이지 않는다. 더 불러올 장이 없다고 확정된 뒤에만.
            // (필터로 0건이 된 페이지 뒤에 다음 장이 남아 있는 동안은 이 분기에 오지 않는다 — 아직
            // "0건 확정"이 아니라 아래 두 분기가 먼저 잡는다.)
            withHeader { centeredIllustration }

        case .loaded where store.state.items.isEmpty && store.state.loadNextFailed:
            // 필터로 0건이 된 페이지 뒤를 자동으로 이어받다 실패한 경우 — 빈 목록으로 위장하지
            // 않고 실패를 그대로 보여준다. 재시도는 실패했던 바로 그 장을 다시 받는 loadNext.
            withHeader {
                centeredStatus(
                    message: "알림을 불러오지 못했어요",
                    kind: .failure(retryTitle: "다시 시도") { store.send(.retryLoadNext) }
                )
            }
            .accessibilityIdentifier("Notification.autoContinueFailed")

        case .loaded where store.state.items.isEmpty:
            // items 는 비었지만 nextRequest 가 남아 있고 실패도 아직 아니다 — 필터로 0건이 된
            // 페이지 뒤를 자동으로 이어받는 중(또는 그 요청이 막 나가려는 찰나).
            withHeader { centeredStatus(message: "알림을 불러오는 중이에요") }
                .accessibilityIdentifier("Notification.autoContinueLoading")

        case .loaded:
            VStack(spacing: 0) {
                NotificationListContentView(
                    notifications: store.state.items,
                    onSelectNotification: { store.send(.tapNotification($0)) },
                    onScrollToEnd: { store.send(.loadNext) }
                )
                if store.state.loadNextFailed {
                    // EC-016 · TS-039 — 목록 전체를 덮지 않고 끝에서만 재시도를 알린다(기존 목록 유지).
                    MHStatusMessage(
                        message: "추가로 불러오지 못했어요",
                        kind: .failure(retryTitle: "다시 시도") { store.send(.retryLoadNext) }
                    )
                    .padding(.vertical, 12)
                    .accessibilityIdentifier("Notification.loadNextFailed")
                }
            }
        }
    }

    private func withHeader(@ViewBuilder _ body: () -> some View) -> some View {
        VStack(spacing: 0) {
            NotificationListHeader()
            body()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.mhBackgroundNormalNormal)
    }

    private func centeredStatus(message: String, kind: MHStatusMessageKind = .progress) -> some View {
        MHStatusMessage(message: message, kind: kind)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var centeredIllustration: some View {
        MHIllustratedMessage(
            illustration: .mhAssetIfAvailable("notificationEmptyIllustration", bundle: .module),
            // Figma 006-1-2: 일러스트 173x173, bottom(301+173=474) → 문구 top(499) 간격 = 25.
            illustrationSize: 173,
            title: "받은 알림이 없어요",
            illustrationSpacing: 25
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("Notification.empty")
    }
}

// MARK: - Preview

/// 정해진 페이지 하나만 돌려주는 프리뷰용 UseCase.
/// `MockNotificationRepository` 가 실 API 로 교체되면서 사라진 자리를 대신한다 — 빈 상태·목록을
/// 시안과 대조할 수단이 없으면 그 화면들은 아무도 다시 안 본다.
private struct PreviewFetchNotifications: FetchNotificationsUseCase {
    let page: Page<AppNotification>

    func execute() async throws -> Page<AppNotification> { page }
    func execute(next request: PageRequest) async throws -> Page<AppNotification> { page }
}

/// 프리뷰는 셀을 눌러 이동하지 않는다 — 도착지 조회는 항상 실패시켜 스낵바 경로만 살려 둔다.
private struct PreviewFailingFetch: FetchPinDetailUseCase, FetchRoomUseCase {
    func execute(pinID: PinID) async throws -> PinDetail { throw DomainError.pinsFetchFailed }
    func execute(id: String) async throws -> Room { throw DomainError.roomsFetchFailed }
}

@MainActor
private func previewStore(_ items: [AppNotification]) -> NotificationListStore {
    NotificationListStore(
        NotificationListState(),
        reduce: notificationListReducer(
            useCase: PreviewFetchNotifications(
                page: Page(items: items, page: 0, pageSize: 20, hasNext: false)
            ),
            fetchPinDetail: PreviewFailingFetch(),
            fetchRoom: PreviewFailingFetch()
        )
    )
}

#Preview("빈 상태") {
    NotificationListContainerView(store: previewStore([]))
}

#Preview("목록") {
    NotificationListContainerView(store: previewStore([
        AppNotification(
            id: NotificationID("1"), type: .duplicateSave,
            title: "이미 저장해둔 곳이에요", targetName: "패스트리 순간", thumbnailURL: nil,
            destination: .place(pinID: PinID("pin-1")), createdAt: .now.addingTimeInterval(-600)
        ),
        AppNotification(
            id: NotificationID("2"), type: .saveError,
            title: "장소를 저장하지 못했어요", targetName: "인스타그램 게시물", thumbnailURL: nil,
            destination: .saveError, createdAt: .now.addingTimeInterval(-7200)
        ),
        AppNotification(
            id: NotificationID("3"), type: .roomJoined,
            title: "방에 참가했어요", targetName: "맛집 탐방", thumbnailURL: nil,
            destination: .room(roomID: "room-1"), createdAt: .now.addingTimeInterval(-864_000)
        ),
    ]))
}
