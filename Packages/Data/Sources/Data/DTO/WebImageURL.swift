import Foundation

/// 문자열을 **사진 주소일 때만** URL 로 받아들인다. http(s) 절대 주소가 아니면 버린다.
///
/// `URL(string:)` 만으로는 못 거른다 — `URL(string: "gray")` 는 스킴 없는 **상대 URL 로 성공**해서
/// 색상 키·플레이스홀더 문자열이 사진으로 둔갑한다. 실제로 방 목록의 `thumbnailList` 는 저장된 핀이
/// 없으면 사진 대신 색상 키(`["gray"]`)를 준다. 그래서 스킴까지 본다.
///
/// DTO 두 곳(`RoomDTO.thumbnailList` · `NotificationDTO.thumbnailUrl`)이 같은 함정을 막고 있어
/// 한 자리에 모았다 — 복제하면 한쪽만 고쳐지고 다른 쪽이 조용히 남는다.
/// [Convention] 삭제된 `ISO8601Date.swift` 처럼 DTO 가 공유하는 파싱 조각은 자유 함수로 둔다.
func webImageURL(_ raw: String?) -> URL? {
    guard let raw, let url = URL(string: raw),
          let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https"
    else { return nil }
    return url
}
