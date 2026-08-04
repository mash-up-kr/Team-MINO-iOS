import DesignSystem
import SwiftUI

/// 튜토리얼 2단계 — 공유 버튼을 누르면 올라오는 공유 대상 시트. Figma `000-2. 공유 대상 클릭`(node 1529:84617).
///
/// 딤 + 바텀시트만 그리는 오버레이라 아래 화면은 포함하지 않는다(실제로는 1단계 위에 얹힌다).
/// 시트 안 검색창·아바타 그리드는 **탭 대상이 아닌 배경 장식**이라 placeholder 로 둔다 — Figma 원본도 같다.
struct TutorialShareTargetContent: View {
    var onTapShareTarget: () -> Void = {}
    var onTapCopyLink: () -> Void = {}
    var onTapDownload: () -> Void = {}
    var onTapMessage: () -> Void = {}

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.mhMaterialDimmer
                .ignoresSafeArea()
            sheet
        }
    }

    // MARK: - Sheet

    private var sheet: some View {
        VStack(spacing: 0) {
            grabber
            targetPlaceholders
            actionBar
        }
        .frame(maxWidth: .infinity)
        .background(Color.mhBackgroundElevatedAlternative)
        .clipShape(sheetShape)
        .overlay { sheetShape.strokeBorder(Color.mhPrimaryNormal, lineWidth: 1.5) }
        .ignoresSafeArea(edges: .bottom)
    }

    private var sheetShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20)
    }

    private var grabber: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.mhFillNormal)
            .frame(width: 38, height: 4)
            .frame(height: 30)
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
            actionItem(icon: .upload, title: "공유 대상", isPrimary: true, action: onTapShareTarget)
            Spacer(minLength: 0)
            actionItem(icon: .link, title: "링크 복사", isPrimary: false, action: onTapCopyLink)
            Spacer(minLength: 0)
            actionItem(icon: .download, title: "다운로드", isPrimary: false, action: onTapDownload)
            Spacer(minLength: 0)
            actionItem(icon: .bubble, title: "메시지", isPrimary: false, action: onTapMessage)
        }
        .overlay(alignment: .topLeading) {
            // 첫 항목(공유 대상) 위 8pt 에 말풍선 바닥이 닿게 — top 가이드를 자기 바닥으로 옮겨 위로 밀어낸다.
            MHTooltip("공유 대상을 눌러주세요", position: .top, align: .start)
                .fixedSize()
                .alignmentGuide(.top) { $0[.bottom] + 8 }
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
        isPrimary: Bool,
        action: @escaping () -> Void
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
    }
}

#Preview {
    ZStack {
        TutorialShareGuideContent()
        TutorialShareTargetContent()
    }
}
