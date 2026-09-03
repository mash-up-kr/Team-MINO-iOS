import SwiftUI
import Testing
@testable import MapUI

@Suite("MarkerDiff — id 기준 증분 diff 판단")
struct MarkerDiffTests {
    private func marker(_ id: String, lat: Double = 37.5, lng: Double = 127.0, title: String? = nil) -> MapMarker {
        MapMarker(id: id, coordinate: MapCoordinate(latitude: lat, longitude: lng), title: title)
    }

    @Test("빈 상태에서 새 마커는 전부 inserted")
    func insertAll() {
        let new = [marker("a"), marker("b")]
        let diff = MarkerDiff.between(applied: [], new: new)
        #expect(diff == MarkerDiff(removedIDs: [], inserted: new, updated: []))
    }

    @Test("새 목록에 없는 id 만 removed, 유지되는 마커는 건드리지 않는다")
    func removeOnlyMissing() {
        let kept = marker("a")
        let diff = MarkerDiff.between(applied: [kept, marker("b")], new: [kept])
        #expect(diff == MarkerDiff(removedIDs: ["b"], inserted: [], updated: []))
    }

    @Test("같은 id 에 값이 바뀐 마커만 updated")
    func updateOnlyChanged() {
        let unchanged = marker("a")
        let moved = marker("b", lat: 38.0, title: "이동")
        let diff = MarkerDiff.between(
            applied: [unchanged, marker("b")],
            new: [unchanged, moved]
        )
        #expect(diff == MarkerDiff(removedIDs: [], inserted: [], updated: [moved]))
    }

    @Test("제거·추가·갱신이 한 번에 섞여도 각각 분류된다")
    func mixed() {
        let unchanged = marker("keep")
        let updated = marker("move", lat: 36.0)
        let inserted = marker("new")
        let diff = MarkerDiff.between(
            applied: [unchanged, marker("move"), marker("gone")],
            new: [unchanged, updated, inserted]
        )
        #expect(diff == MarkerDiff(removedIDs: ["gone"], inserted: [inserted], updated: [updated]))
    }

    @Test("좌표가 같아도 스타일만 바뀌면 updated — 선택 마커 아이콘 교체가 이 경로로 반영된다")
    func styleChangeIsUpdate() {
        let plain = marker("a")
        let selected = MapMarker(
            id: "a",
            coordinate: MapCoordinate(latitude: 37.5, longitude: 127.0),
            style: MapMarkerStyle(tint: .red, isSelected: true)
        )
        let diff = MarkerDiff.between(applied: [plain], new: [selected])
        #expect(diff == MarkerDiff(removedIDs: [], inserted: [], updated: [selected]))
    }

    @Test("중복 id 는 첫 항목 기준으로 판단한다")
    func duplicateIDsFirstWins() {
        let first = marker("dup", title: "첫째")
        let second = marker("dup", title: "둘째")
        let diff = MarkerDiff.between(applied: [], new: [first, second])
        #expect(diff == MarkerDiff(removedIDs: [], inserted: [first], updated: []))
    }
}
