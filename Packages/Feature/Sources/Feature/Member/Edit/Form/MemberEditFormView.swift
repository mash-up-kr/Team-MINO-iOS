import SwiftUI

/// sheet 자식 flow 의 진입 화면(편집 폼). 저장/취소를 자식 Coordinator 에 알리면
/// `FlowFinish` → `flowRoot` 경로로 부모가 결과를 받고 시트가 닫힌다.
struct MemberEditFormView: View {
    let coordinator: MemberEditCoordinator
    @State private var name: String = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("이름", text: $name)
            }
            .navigationTitle("편집")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { coordinator.cancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { coordinator.save(name) }
                }
            }
        }
    }
}
