/// 마커 증분 적용의 판단부(id 기준 diff). GMSMarker 조작(`MapView.Coordinator.apply`)과 분리해
/// 플랫폼 비의존으로 두고, 호스트(macOS)에서 단위 테스트한다.
struct MarkerDiff: Equatable {
    let removedIDs: Set<String>
    let inserted: [MapMarker]
    let updated: [MapMarker]

    /// 같은 id 가 중복되면 첫 항목 기준으로 판단한다.
    static func between(applied: [MapMarker], new: [MapMarker]) -> MarkerDiff {
        let appliedByID = Dictionary(applied.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let newIDs = Set(new.map(\.id))

        var inserted: [MapMarker] = []
        var updated: [MapMarker] = []
        var seenIDs = Set<String>()
        for marker in new {
            guard seenIDs.insert(marker.id).inserted else { continue }
            if let existing = appliedByID[marker.id] {
                if existing != marker {
                    updated.append(marker)
                }
            } else {
                inserted.append(marker)
            }
        }
        return MarkerDiff(
            removedIDs: Set(appliedByID.keys).subtracting(newIDs),
            inserted: inserted,
            updated: updated
        )
    }
}
