import DesignSystem
import SwiftUI

/// 튜토리얼 2단계 — 공유 버튼을 누르면 올라오는 공유 대상 시트. Figma `000-1-2 튜토리얼_step 4`(node 2314:58901).
///
/// 시트만 그린다 — 딤은 ``TutorialView`` 가 그린다. 시트는 아래에서 올라오고 딤은 페이드라
/// 전환이 서로 달라서, 한 뷰로 묶으면 딤까지 아래에서 밀려 올라온다.
/// 시트 안 검색창·아바타 그리드는 **탭 대상이 아닌 배경 장식**이라 placeholder 로 둔다 — Figma 원본도 같다.
struct TutorialShareTargetContent: View {
    /// 튜토리얼이 진행되는 유일한 경로. 나머지 액션(링크 복사·다운로드·메시지)은 Figma 에 있으니
    /// 그리기는 하되 **누르면 아무 일도 일어나지 않는다** — 정해진 흐름만 따라가게 하려는 의도다.
    var onTapShareTarget: () -> Void = {}

    var body: some View {
        sheet
    }

    // MARK: - Sheet

    private var sheet: some View {
        VStack(spacing: 0) {
            grabber
            targetPlaceholders
            actionBar
        }
        .frame(maxWidth: .infinity)
        // 배경만 안전영역 밖으로 늘린다 — 시트에 clipShape 를 걸면 크기가 콘텐츠에 고정돼
        // 바깥에서 ignoresSafeArea 를 걸어도 홈 인디케이터 띠가 딤인 채로 남는다.
        .background {
            sheetShape
                .fill(Color.mhBackgroundElevatedAlternative)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private var sheetShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20)
    }

    private var grabber: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.mhFillNormal)
            .frame(width: 38, height: 4)
            .frame(height: 30)
            .accessibilityHidden(true)
    }

    // MARK: - 배경 장식(검색 + 아바타 그리드)

    // 높이 225 고정 — 아바타 둘째 줄이 잘리는 건 의도된 디자인이다(Figma 도 시트 높이 393 안에서 잘라 보여준다).
    private var targetPlaceholders: some View {
        VStack(spacing: 24) {
            searchRow
            avatarGrid
        }
        .padding(.horizontal, 20)
        .frame(height: 225, alignment: .top)
        .clipped()
    }

    private var searchRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(MHIcon.search)
                    .resizable()
                    .frame(width: 16, height: 16)
                    .foregroundStyle(Color.mhLabelNeutral)
                // 실제 입력 필드가 아니라 시트 배경 장식이라 TextField 가 아닌 Text 다(입력 폰트 규칙 대상 아님).
                Text("검색")
                    .mhTypography(.body1ReadingRegular)
                    .foregroundStyle(Color.mhLabelNeutral)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.mhFillNormal, in: RoundedRectangle(cornerRadius: 20))

            Image(MHIcon.persons)
                .resizable()
                .frame(width: 16, height: 16)
                .foregroundStyle(Color.mhLabelNeutral)
                .padding(12)
                .background(Color.mhFillNormal, in: RoundedRectangle(cornerRadius: 20))
        }
        // 탭 대상이 아닌 시트 배경 장식(검색창 목업) — 아래 avatarGrid 와 같은 취급.
        .accessibilityHidden(true)
    }

    private var avatarGrid: some View {
        VStack(spacing: 28) {
            ForEach(0..<2, id: \.self) { _ in
                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { column in
                        VStack(spacing: 12) {
                            MHAvatar(nil, size: 70)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.mhFillNormal)
                                .frame(width: 40, height: 10)
                        }
                        if column < 2 { Spacer(minLength: 0) }
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .accessibilityHidden(true)
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: 0) {
            actionItem(icon: .upload, title: "공유 대상", identifier: "shareTarget", isPrimary: true, action: onTapShareTarget)
            Spacer(minLength: 0)
            actionItem(icon: .link, title: "링크 복사", identifier: "copyLink", isPrimary: false)
            Spacer(minLength: 0)
            actionItem(icon: .download, title: "다운로드", identifier: "download", isPrimary: false)
            Spacer(minLength: 0)
            actionItem(icon: .bubble, title: "메시지", identifier: "message", isPrimary: false)
        }
        .overlay(alignment: .topLeading) {
            // 첫 항목(공유 대상) 위 8pt 에 말풍선 바닥이 닿게 — top 가이드를 자기 바닥으로 옮겨 위로 밀어낸다.
            MHTooltip("공유 대상을 눌러주세요", position: .top, align: .start)
                .fixedSize()
                .alignmentGuide(.top) { $0[.bottom] + 8 }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("TutorialShareTarget.tooltip")
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 32)
        .background(Color.mhBackgroundNormalNormal)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.mhLineNormalNeutral)
                .frame(height: 1)
        }
    }

    private func actionItem(
        icon: MHIcon,
        title: String,
        identifier: String,
        isPrimary: Bool,
        action: @escaping () -> Void = {}
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(icon)
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(isPrimary ? Color.mhStaticWhite : Color.mhLabelNormal)
                    .frame(width: 62, height: 62)
                    .background(
                        isPrimary ? Color.mhPrimaryNormal : Color.mhBackgroundNormalAlternative,
                        in: Circle()
                    )
                Text(title)
                    .mhTypography(isPrimary ? .label2Bold : .label2Medium)
                    .foregroundStyle(Color.mhLabelNormal)
            }
        }
        .accessibilityIdentifier("TutorialShareTarget.\(identifier)")
    }
}

#Preview {
    ZStack {
        TutorialShareGuideContent()
        Color.mhMaterialDimmer.ignoresSafeArea()
        TutorialShareTargetContent()
    }
}
