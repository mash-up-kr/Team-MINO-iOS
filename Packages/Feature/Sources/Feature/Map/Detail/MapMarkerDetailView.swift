import SwiftUI

/// 마커 상세 화면. 지금은 push 라우팅 도착을 확인하는 최소 뷰 — 마커 id 만 표시한다.
/// (도메인 데이터 연동 시 실제 상세 Store/화면으로 확장)
struct MapMarkerDetailView: View {
    let markerID: String

    var body: some View {
        VStack(spacing: 8) {
            Text("마커 상세")
                .font(.title2)
            Text(markerID)
                .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("상세")
    }
}
