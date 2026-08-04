import SwiftUI

// MARK: - Room Header

/// 방(Room) 화면 상단 헤더. Figma `Header_Room`(show memo = on / off, node 15852:88515).
///
/// 제목 + (선택) 메모 부제 + 메타 행(위치 아이콘 + 개수, 우측 아이콘 버튼) + 하단 구분선으로 구성된다.
/// `memo` 가 `nil` 이면 Figma `show memo=off`(제목만) 상태가 된다.
///
/// 제목·메모는 한 줄로 말줄임(…)한다. 메타 행은 좌측에 위치 아이콘과 개수 텍스트, 우측에 썸네일 등
/// 아이콘 버튼(`trailingAction` 을 줄 때만)을 둔다. 아이콘은 기본값(위치·썸네일)을 바꿀 수 있다.
///
/// ```swift
/// MHRoomHeader(title: "스터디룸", memo: "매주 목 저녁", count: "999+개") { openGallery() }
/// MHRoomHeader(title: "제목만", count: "12개")                          // 메모 없음(off)
/// ```
public struct MHRoomHeader: View {
    private let title: String
    private let memo: String?
    private let count: String
    private let locationIcon: MHIcon
    private let trailingIcon: MHIcon
    private let trailingAction: (() -> Void)?

    public init(
        title: String,
        memo: String? = nil,
        count: String,
        locationIcon: MHIcon = .locationFill,
        trailingIcon: MHIcon = .thumbnail,
        trailingAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.memo = memo
        self.count = count
        self.locationIcon = locationIcon
        self.trailingIcon = trailingIcon
        self.trailingAction = trailingAction
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                text(title, .title3Bold, .mhLabelStrong)
                if let memo {
                    text(memo, .label1NormalRegular, .mhLabelNeutral)
                }
            }
            metaRow
        }
        .padding(.top, 12)
        .padding(.bottom, 20)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.mhLineSolidAlternative).frame(height: 1)
        }
    }

    // 한 줄 말줄임 텍스트. `.mhTypography` 를 View(=lineLimit 이후) 에 적용해 Figma 라인박스(행간 포함)를 그대로 얻는다.
    private func text(_ string: String, _ token: MHTypography, _ color: Color) -> some View {
        Text(string)
            .lineLimit(1)
            .truncationMode(.tail)
            .foregroundStyle(color)
            .mhTypography(token)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // 좌: 위치 아이콘 + 개수 / 우: 아이콘 버튼. Figma: items-end(바닥 정렬), justify-between.
    private var metaRow: some View {
        HStack(alignment: .bottom, spacing: 0) {
            HStack(spacing: 2) {
                Image(locationIcon)
                    .resizable().scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(.mhLabelAlternative)
                Text(count)
                    .lineLimit(1)
                    .foregroundStyle(.mhLabelAlternative)
                    .mhTypography(.label1NormalRegular)
            }
            Spacer(minLength: 0)
            if let trailingAction {
                iconButton(trailingIcon, action: trailingAction)
            }
        }
    }

    // 썸네일 등 아이콘 버튼(24pt, Button/Icon/Normal). 눌림 시 8px 큰 원형 halo(Label/Normal, Light 인터랙션).
    private func iconButton(_ icon: MHIcon, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(icon)
                .resizable().scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundStyle(.mhLabelAlternative)
        }
        .buttonStyle(MHRoomHeaderIconButtonStyle())
    }
}

// MARK: - ButtonStyle (아이콘 버튼 press halo)

// Figma `Interaction/Light`(inset-[-8px] Label/Normal rounded-full). 눌렀을 때 아이콘보다 8px 큰 원형 halo.
// 정확한 불투명도는 Figma 가 링크 페이지라 미실측 → Label/Normal 0.06 근사(플래그).
struct MHRoomHeaderIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                if configuration.isPressed {
                    Circle()
                        .fill(Color.mhLabelNormal.opacity(0.06))
                        .frame(width: 24 + 16, height: 24 + 16)   // inset -8 → 40pt halo
                }
            }
    }
}

#Preview("MHRoomHeader") {
    VStack(spacing: 0) {
        MHRoomHeader(title: "Title", memo: "memo", count: "999+개") { }   // show memo = on
        MHRoomHeader(title: "Title", count: "999+개") { }                  // show memo = off
    }
    .frame(width: 375)
    .padding(.vertical)
}
