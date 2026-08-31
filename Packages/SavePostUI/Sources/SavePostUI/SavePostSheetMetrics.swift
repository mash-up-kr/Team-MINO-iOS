import CoreGraphics

/// 게시물 저장 시트의 높이 단계. Figma 013-1 ① 스펙(node 2792:175979).
///
/// **개수 분기가 아니라 드래그 단계다.** 같은 방 4개짜리 시안이 peek(node 2792:176010, 436)과
/// full(node 2792:176059, 612) 둘 다 존재한다. 스펙 원문도 `peek : … 436px(고정값)` /
/// `full_4개 : … 612px(고정값)` / `full_4개 이상 : … 644px(고정값)` 로 나눠 적는다 —
/// peek 은 방 개수와 무관하게 436 이고, 방 개수로 갈리는 건 full 뿐이다.
public enum SavePostSheetDetent: Equatable, Sendable, CaseIterable {
    case peek
    case full
}

/// 게시물 저장 시트의 높이 규칙. 값은 전부 action area 를 포함한 시트 전체 높이다.
///
/// | 단계 | 방 개수 | 시안 높이 | 목록 뷰포트 | 보이는 카드 |
/// |---|---|---|---|---|
/// | `peek` | 전부 | 436 | 240 | 2장 + 3번째 32 잘림 |
/// | `full` | 3개 이하 | 436 | 240 | (peek 과 같다 — 스펙에 full 이 없다) |
/// | `full` | 4개 | 612 | 416 | 4장 |
/// | `full` | 5개 이상 | 644 | 448 | 4장 + 5번째 32 잘림 |
///
/// 목록 뷰포트는 시안 프레임 `Frame 280` 실측값이고(240 / 416 / 448), 시트 높이는 거기서
/// 산술로 떨어진다: **높이 = 헤더 94 + 목록 + 액션 상단 68 + 하단 34**.
/// 헤더 94 = 그래버 30 + 텍스트 52(28+4+20) + 하단 12, 액션 상단 68 = 패딩 20 + 버튼 48(`MHButton` large).
///
/// ## 하단 34 를 기기 인셋으로 갈아끼우는 법
///
/// 시안의 `Action Area` 는 **102** 다 — 컨테이너 88 + `Bottom Safe Area` **14**
/// (node `I2792:176725;16215:35685;16215:35714`). 프레임의 홈 인디케이터는 34 인데 슬롯이 14 뿐이라는 건,
/// 컨테이너 자신의 하단 패딩 20 이 이미 인디케이터 영역 안에 들어가 있다는 뜻이다(20 + 14 = 34).
///
/// 그래서 인셋 S 로 갈아끼울 때 34 를 빼고 S 를 더하는 게 아니라 **`max(20, S)`** 를 더한다.
/// 버튼 아래 여백은 항상 `max(20, S)` — 인디케이터가 없는 기기(SE)에서도 20 은 남는다.
/// 이 규칙이라야 시안 세 프레임의 목록 뷰포트(240 / 416 / 448)가 그대로 재현된다.
/// 34 를 통째로 더하면 액션 영역이 122 가 되어 목록이 20 씩 줄고, 612 에서 "카드 4개 전체"가 깨진다.
public enum SavePostSheetMetrics {
    /// 시안 기기의 하단 safe-area(홈 인디케이터).
    public static let designSafeAreaBottom: CGFloat = 34

    /// 시트 상단의 고정(비스크롤) 영역 — 그래버 30 + 헤더 64. 시안 `Frame 522`.
    /// 목록 위 드래그를 스크롤로 남겨 두려면 단계 전환 드래그를 이 영역에서만 받는다.
    public static let headerHeight: CGFloat = 94

    /// 액션 영역 컨테이너 높이 — 상단 20 + 버튼 48 + 하단 20. 시안 `Action Area > Contents` 88.
    static let actionAreaContentHeight: CGFloat = 88

    /// 컨테이너 자체의 하단 패딩. 시안은 이 20 이 홈 인디케이터 영역 안에 들어가 있다고 본다.
    static let actionAreaBottomPadding: CGFloat = 20

    /// 액션 영역 아래에 호출부가 직접 깔아야 하는 띠 높이.
    /// 컨테이너 하단 패딩 20 을 제하고 남는 만큼만 — 시안 기기(34)에서 14 로 `Bottom Safe Area` 와 같다.
    static func actionAreaBottomBand(safeAreaBottom: CGFloat) -> CGFloat {
        max(0, safeAreaBottom - actionAreaBottomPadding)
    }

    public static func height(
        _ detent: SavePostSheetDetent,
        roomCount: Int,
        safeAreaBottom: CGFloat
    ) -> CGFloat {
        designHeight(detent, roomCount: roomCount)
            - designSafeAreaBottom
            + max(actionAreaBottomPadding, safeAreaBottom)
    }

    /// 홈 카드 `다른 방 저장` 진입(002-5)의 시트 높이 — **방 개수와 무관하게 644 고정**이다.
    ///
    /// 013-1 ① 의 peek/full 단계와 개수 분기는 **외부 공유 수신** 진입의 규칙이다. 홈 진입은
    /// 주석 002-5(node `2862-175523`) ② 가 "높이 644px 고정 / 방 리스트 스크롤 영역 448px 고정" 으로
    /// 따로 못박아 두었다 — 그래서 단계도 개수 분기도 두지 않는다.
    ///
    /// 값 자체는 `full`·5개 이상과 같지만 **이유가 다르다**. 같다고 그쪽을 부르면 방이 4개인 계정에서
    /// 612 로 줄어 주석과 어긋나므로, 여기서 높이를 직접 고정한다.
    public static func homeEntryHeight(safeAreaBottom: CGFloat) -> CGFloat {
        homeEntryDesignHeight - designSafeAreaBottom + max(actionAreaBottomPadding, safeAreaBottom)
    }

    /// 시안 기기(홈 인디케이터 34) 기준 홈 진입 높이.
    /// 그래버 30 + 헤더 64 + 목록 448 + Action Area 102 = 644.
    static let homeEntryDesignHeight: CGFloat = 644

    /// 시안 기기(홈 인디케이터 34) 기준 시트 높이.
    static func designHeight(_ detent: SavePostSheetDetent, roomCount: Int) -> CGFloat {
        switch detent {
        case .peek: 436
        case .full:
            switch roomCount {
            case 5...: 644
            case 4: 612
            default: 436   // 스펙에 full 이 없다 — peek 과 같은 높이라 사실상 단계가 하나다
            }
        }
    }
}
