import Foundation

/// 코멘트 작성 시각을 표시용 문자열로 바꾸는 순수 함수.
///
/// 배치 시안이 없어(Figma 005 장소 상세 주석10 — "런칭 이후" 미구현 항목) `MHComment.dateText`
/// 로 넘길 문자열만 여기서 만든다. 문자열 계산이 DS 몫이 아니라는 원칙(디자인 토큰만으로 그려지는
/// 순수 부품만 DS 에 둔다 — `Packages/DesignSystem/README.md`) 을 지키기 위해 화면 쪽(PlaceDetailUI)
/// 에 둔다.
///
/// 규칙(기획서 원문):
///   - 작성 후 10일까지는 상대 시간 — 방금 전 / N분 전 / N시간 전 / N일 전
///   - 작성 후 11일부터는 절대 날짜 — `yyyy.MM.dd`
///
/// 날짜 경계는 **캘린더 날짜 기준**(`startOfDay` 차이)이다. 24시간 버킷이 아니라서, 자정을 살짝
/// 넘긴 1분 전 코멘트도 "1일 전"이 된다 — ``PlaceDetailUITests/CommentDateTextTests`` 의 자정
/// 경계 케이스 참조.
enum CommentDateText {
    /// - Parameters:
    ///   - createdAt: 코멘트 작성 시각.
    ///   - now: 기준 시각. `PlaceDetailCommentSection` 이 View 에서 만들어 넘긴다(reduce/State 순수성 유지).
    ///   - calendar: 캘린더 일 수 계산과 절대 날짜 포맷에 함께 쓴다 — 테스트가 결정적이도록 호출부가 고정해 넘긴다.
    static func text(for createdAt: Date, now: Date, calendar: Calendar) -> String {
        // 미래(시계 어긋남 포함)는 "방금 전"으로 흡수한다.
        guard createdAt <= now else { return "방금 전" }

        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: createdAt),
            to: calendar.startOfDay(for: now)
        ).day ?? 0

        if days >= 11 {
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.locale = calendar.locale
            formatter.dateFormat = "yyyy.MM.dd"
            return formatter.string(from: createdAt)
        }

        if days >= 1 {
            return "\(days)일 전"
        }

        // days == 0(오늘 안): 시안이 없어 다음으로 가정한다 — 1분 미만 "방금 전",
        // 1시간 미만 "N분 전", 그 외(23시간대까지) "N시간 전".
        let elapsed = now.timeIntervalSince(createdAt)
        if elapsed < 60 {
            return "방금 전"
        }
        if elapsed < 3600 {
            return "\(Int(elapsed / 60))분 전"
        }
        return "\(Int(elapsed / 3600))시간 전"
    }
}
