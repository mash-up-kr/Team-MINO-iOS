import DesignSystem
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
        // TODO: 디자이너 에셋 전달 대기. 도착 전까지는 일러스트가 접히고 문구만 보인다.
        MHIllustratedMessage(
            illustration: .mhAssetIfAvailable("notificationEmptyIllustration", bundle: .module),
            title: "받은 알림이 없어요"
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("Notification.empty")
    }
}
