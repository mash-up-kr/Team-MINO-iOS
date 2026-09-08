import Domain
import Foundation
import MapUI

/// 지도 축소 시 겹치는 핀을 묶는 판정부.
///
/// PRD [SYS-004] Flow C — *"**지도 축소 시:** 핀이 겹치는 구간을 클러스터로 묶는다. **1~99개는
/// `50+` 식 숫자 표기 클러스터**, **100개 이상은 `100+` 클러스터** 아이콘으로 표시한다."*
///
/// **새 의존을 들이지 않는다.** GoogleMaps 유틸(`GMUClusterManager`)은 마커 수명을 직접 관리해
/// 이 레포의 `MarkerDiff` 파이프라인과 충돌하고, 아이콘도 시안대로 자작해야 해서 얻을 것이 적다.
/// 대신 **화면 픽셀 격자**로 묶는다 — 같은 셀에 떨어지는 핀은 화면에서 실제로 겹치는 핀이다.
///
/// **순수 계산이지만 호스트 테스트는 아니다.** `PlaceMapUI` 는 `DesignSystem`(unguarded
/// `import UIKit`)을 의존해 iOS 전용이고(`Package.swift` 의 `platforms: [.iOS(.v17)]` 과 그
/// 주석), 그래서 `PlaceMapUITests` 는 시뮬레이터에서 돈다. 지도를 띄우지 않고 검증한다는 이점은
/// 그대로다 — SDK 조작과 판단을 갈라 둔 `MapUI` 의 `MarkerDiff` 와 같은 결이다.
///
/// 호스트에서 돌려야 하는 계산이 생기면 `MapUI`(macOS 선언)로 내린다 — 라벨 줄바꿈
/// (`MarkerLabel`)이 그 자리에 있다.
public extension PlaceMap {
    /// 클러스터를 만들기 시작하는 셀 크기(화면 pt). 마커 폭 48 보다 조금 크게 잡아, 셀이 다르면
    /// 두 마커가 서로 닿지 않도록 한다.
    static var clusterCellSize: Double { 64 }

    /// 클러스터 카운트 표기. 규칙은 ``MapUI/MapMarkerKind/clusterCountText(_:)`` 하나뿐이고
    /// 여기서는 그 이름으로 부를 수 있게 넘겨만 준다 — 그림(`MapView`)과 판정(`PlaceMap`)이 같은
    /// 규칙을 봐야 한다.
    static func clusterCountText(_ count: Int) -> String {
        MapMarkerKind.clusterCountText(count)
    }

    /// 줌을 정수 단계로 내린다.
    ///
    /// 카메라가 멈출 때마다 셀 크기가 미세하게 달라지면 클러스터 구성이 계속 바뀌어 `MarkerDiff`
    /// 가 헛돌고 마커가 깜박인다. 같은 정수 줌 안에서는 같은 결과가 나오게 고정한다.
    static func quantized(zoom: Float) -> Float { zoom.rounded(.down) }

    /// 핀을 클러스터·단독 마커로 나눠 그린다.
    ///
    /// - Parameters:
    ///   - zoom: 지금 카메라 줌. `nil` 이면 기본 카메라 줌으로 본다.
    ///   - selectedPinID: 지금 장소 상세로 열려 있는 핀. **이 핀은 묶지 않는다** — 묶이면 방금
    ///     고른 장소가 클러스터 안으로 사라진다.
    /// - Returns: 클러스터(구성원 2개 이상)와 단독 마커가 섞인 배열.
    static func clustered(
        pins: [Pin],
        zoom: Float?,
        roomColors: [String: RoomColor],
        selectedPinID: String?,
        showsLabels: Bool
    ) -> [MapMarker] {
        let level = quantized(zoom: zoom ?? defaultCamera.zoom)
        // 선택된 핀은 클러스터 판정에서 빼 둔 뒤 단독 마커로 되돌린다.
        let selected = pins.filter { $0.id.value == selectedPinID }
        let clusterable = pins.filter { $0.id.value != selectedPinID }

        var cells: [Cell: [Pin]] = [:]
        for pin in clusterable {
            cells[Cell(pin.place.coordinate, zoom: level), default: []].append(pin)
        }

        // 셀 순서가 지도에 그리는 순서라 매번 같아야 한다 — 딕셔너리 순서는 보장되지 않는다.
        let grouped = cells.sorted { ($0.key.x, $0.key.y) < ($1.key.x, $1.key.y) }
        let grid: [MapMarker] = grouped.flatMap { cell, members -> [MapMarker] in
            guard members.count > 1 else {
                return markers(
                    pins: members,
                    roomColors: roomColors,
                    selectedPinID: selectedPinID,
                    showsLabels: showsLabels
                )
            }
            return [clusterMarker(cell: cell, members: members, roomColors: roomColors)]
        }

        // 선택된 핀을 마지막에 붙인다 — 지도가 뒤에 온 마커를 위에 그린다.
        return grid + markers(
            pins: selected,
            roomColors: roomColors,
            selectedPinID: selectedPinID,
            showsLabels: showsLabels
        )
    }

    /// 클러스터 하나. 좌표는 구성원의 평균이라 묶인 자리 가운데에 선다.
    ///
    /// 색은 **구성원이 모두 한 방일 때만** 그 방 색을 쓰고, 여러 방이 섞이면 기본 회색이다 —
    /// PRD 는 마커 색을 "속한 방의 대표 색상" 으로 정했을 뿐 여러 방이 섞인 클러스터의 색을 정하지
    /// 않았다(플래그). 한 방의 색을 임의로 골라 쓰면 그 방에만 속한 것처럼 읽힌다.
    private static func clusterMarker(
        cell: Cell,
        members: [Pin],
        roomColors: [String: RoomColor]
    ) -> MapMarker {
        let rooms = Set(members.map(\.roomID))
        let color = rooms.count == 1 ? rooms.first.flatMap { roomColors[$0] } : nil

        return MapMarker(
            // 셀 좌표를 id 로 쓴다 — 같은 줌에서 같은 클러스터가 같은 id 를 가져야
            // `MarkerDiff` 가 "그대로 있다" 로 판단해 마커를 다시 만들지 않는다.
            id: clusterIDPrefix + "\(cell.x):\(cell.y)",
            coordinate: MapCoordinate(
                latitude: members.map(\.place.coordinate.latitude).reduce(0, +) / Double(members.count),
                longitude: members.map(\.place.coordinate.longitude).reduce(0, +) / Double(members.count)
            ),
            // 클러스터에는 장소명을 달지 않는다 — 어느 장소의 이름인지 정할 수 없다.
            title: nil,
            style: MapMarkerStyle(tint: tint(for: color), kind: .cluster(count: members.count))
        )
    }

    /// 클러스터 마커의 id 접두사. 탭 이벤트에서 "장소 하나" 와 "묶음" 을 가르는 표시다.
    static var clusterIDPrefix: String { "cluster:" }

    /// 이 id 가 클러스터인가. 탭했을 때 상세를 열 수 있는 id 인지 가른다.
    static func isClusterID(_ id: String) -> Bool { id.hasPrefix(clusterIDPrefix) }

    /// 화면 픽셀 격자의 한 칸.
    ///
    /// Web Mercator 투영(Google 규약: 줌 0 에서 세계가 256pt)으로 좌표를 화면 픽셀로 옮긴 뒤
    /// ``clusterCellSize`` 로 나눈다 — 위도가 높아질수록 같은 경도차가 화면에서 좁아지는 것을
    /// 투영이 알아서 반영한다(경위도를 그대로 격자로 쓰면 고위도에서 과하게 묶인다).
    private struct Cell: Hashable {
        let x: Int
        let y: Int

        init(_ coordinate: Coordinate, zoom: Float) {
            let worldSize = 256 * pow(2, Double(zoom))
            let x = (coordinate.longitude + 180) / 360 * worldSize

            // 위도를 Mercator y 로. 극지방에서 무한이 되지 않게 ±85.05112878 로 자른다.
            let latitude = min(max(coordinate.latitude, -85.05112878), 85.05112878)
            let sinLatitude = sin(latitude * .pi / 180)
            let y = (0.5 - log((1 + sinLatitude) / (1 - sinLatitude)) / (4 * .pi)) * worldSize

            self.x = Int((x / PlaceMap.clusterCellSize).rounded(.down))
            self.y = Int((y / PlaceMap.clusterCellSize).rounded(.down))
        }
    }
}
