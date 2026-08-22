import DesignSystem
import FlowCoordination
import RoomCreationUI
import SwiftUI

/// 마이 탭 진입 View. 실제 화면이 붙기 전까지 탭 이름과 방 상세 시트 확인용 버튼만 표시한다.
public struct ProfileTabView: View {
    private let coordinator: ProfileCoordinator

    /// 공유 시트를 띄운 장소. 방 상세 시트는 `MHBottomSheet` 클립 경계 안이라 딤 모달을 자기 안에서 못 띄운다.
    @State private var sharingLocation: RoomDetailLocation?
    /// 시트 dismiss 가 끝난 뒤 띄울 토스트. 닫힘과 같은 프레임에 띄우면
    /// 내려가는 시트가 토스트 자리를 덮어 초반이 가려진 채 시작한다.
    @State private var pendingToast: String?
    @State private var toastMessage: String?
    /// 토스트 발사 횟수. 자동 소멸 타이머의 수명을 문구가 아니라 이 값에 묶는다 —
    /// 같은 문구로 두 번 뜨면 문구를 id 로 쓴 타이머는 재시작하지 않는다.
    @State private var toastToken = 0

    public init(coordinator: ProfileCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        @Bindable var coordinator = coordinator
        NavigationStack(path: $coordinator.path) {
            ZStack {
                VStack(spacing: 16) {
                    Text("마이")
                        .accessibilityIdentifier("ProfileTab.title")

                    MHButton("방 상세 열기", size: .medium) {
                        coordinator.isRoomDetailPresented = true
                    }
                    .accessibilityIdentifier("ProfileTab.openRoomDetail")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // MHBottomSheet 은 딤 없는 비모달이라 .sheet 가 아니라 ZStack 에 겹쳐 놓는다
                if coordinator.isRoomDetailPresented {
                    RoomDetailSheet(
                        room: .sample,
                        locations: RoomDetailLocation.samples,
                        onOutput: handle
                    )
                    .transition(.move(edge: .bottom))
                }

                toast
            }
            .navigationDestination(for: ProfileRoute.self) { route in
                switch route {
                case .roomEdit(let room):
                    // 편집에는 건너뛰기가 없다(showsSkip: false). 뒤로가기는 취소 확인 다이얼로그를 거친다.
                    RoomFormView(makeStore: { coordinator.makeRoomFormStore(room: room) }, showsSkip: false)
                }
            }
            .animation(.spring(duration: 0.3), value: coordinator.isRoomDetailPresented)
            .animation(.easeInOut(duration: 0.2), value: toastMessage)
            .sheet(item: $sharingLocation, onDismiss: {
                if let pendingToast {
                    showToast(pendingToast)
                    self.pendingToast = nil
                }
            }) { location in
                RoomShareSheet(
                    location: location,
                    rooms: RoomShareRoom.samples,
                    onClose: { sharingLocation = nil },
                    onSubmit: { _ in
                        pendingToast = "공유가 완료됐습니다."
                        sharingLocation = nil
                    }
                )
                .presentationDetents([.height(RoomShareSheet.detentHeight)])
                .presentationCornerRadius(20)
                .presentationDragIndicator(.hidden)   // 그래버는 시안대로 시트 안에서 직접 그린다
                .presentationBackground(.mhBackgroundElevatedNormal)
            }
        }
    }

    // 시안 `1672:73661` — 하단에서 102(= 홈 인디케이터 34 + 68), 좌우 20.
    @ViewBuilder private var toast: some View {
        if let toastMessage {
            VStack {
                Spacer()
                MHSnackbar(title: toastMessage, icon: .checkThick)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 68)
            }
            .allowsHitTesting(false)
            .transition(.opacity)
            .task(id: toastToken) {
                // 취소를 삼키면 안 된다. try? 로 받으면 새 토스트가 이 task 를 취소했을 때
                // sleep 이 즉시 반환하고, 이어지는 nil 대입이 **방금 뜬 토스트**를 지운다.
                let token = toastToken
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
                // catch 는 sleep 재개 전 취소만 잡는다. 재개 후 같은 틱에 새 토스트가 뜨는
                // 좁은 창은 토큰 비교로 막는다 — 낡은 타이머는 최신 토스트를 지우면 안 된다.
                guard token == toastToken else { return }
                self.toastMessage = nil
            }
        }
    }

    private func handle(_ output: RoomDetailOutput) {
        switch output {
        case .close:
            coordinator.isRoomDetailPresented = false
        case .shareLocation(let location):
            sharingLocation = location
        case .editRoom(let room):
            // 시트를 먼저 내린다 — 편집에서 돌아왔을 때 시트가 그대로 남아 있어야 자연스럽지만,
            // 지금은 시트가 화면 전체를 덮는 비모달이라 push 화면과 겹친다.
            coordinator.isRoomDetailPresented = false
            coordinator.startRoomEdit(room)
        }
    }

    private func showToast(_ message: String) {
        toastMessage = message
        toastToken += 1
    }
}

#Preview {
    ProfileTabView(coordinator: ProfileCoordinator())
}
