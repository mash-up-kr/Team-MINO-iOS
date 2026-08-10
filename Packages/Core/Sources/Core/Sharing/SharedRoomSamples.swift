import Foundation

// 백엔드 미연결 단계의 표본 방 목록. 지금은 익스텐션이 그릴 방 목록이 이것뿐이다.
// 실제 방 목록 API 가 붙으면 이 파일을 지운다.
public extension SharedRoom {
    static let samples: [SharedRoom] = [
        SharedRoom(id: "1", name: "내 방", memo: "내가 꾹 저장한 장소", placeCount: 12),
        SharedRoom(id: "2", name: "성수 카페 투어", memo: "주말에 가볼 곳", placeCount: 8),
        SharedRoom(id: "3", name: "제주도 여행", placeCount: 24),
        SharedRoom(id: "4", name: "회사 근처 점심", memo: "12시 웨이팅 없는 곳", placeCount: 5),
    ]
}
