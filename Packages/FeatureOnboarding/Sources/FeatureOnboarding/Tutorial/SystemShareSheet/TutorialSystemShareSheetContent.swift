import DesignSystem
import SwiftUI

/// 튜토리얼 3단계 — iOS 시스템 공유시트를 **흉내 낸** 화면. Figma `iOS_시스템 공유시트 표출`(node 2314:58969).
///
/// 진짜 `UIActivityViewController` 가 아니라 직접 그린 목업이다 — 실제로 공유하지 않고 튜토리얼 진행만 시키기
/// 때문이다. 시스템 UI 복제라 색·서체는 우리 디자인 시스템이 아니라 **시스템 색/시스템 폰트(SF)** 를 쓴다.
///
/// 연락처 사진과 애플 기본 앱 아이콘은 번들에 넣을 수 없어 실루엣·근사 타일로 대체했다.
/// Figma 가 AirDrop 자리에 `우리 앱` 이라고 적어둔 첫 칸은 우리 앱(검정 타일 + send)으로 그린다.
struct TutorialSystemShareSheetContent: View {
    var onTapClose: () -> Void = {}
    var onTapAppShare: () -> Void = {}

    /// Figma 행 높이(node 0:56 / 0:118 / 0:136). 한 칸 78pt, 좌우 여백 24pt, 칸 간격 14pt.
    private enum Layout {
        static let sidePadding: CGFloat = 24
        static let itemWidth: CGFloat = 78
        static let itemSpacing: CGFloat = 14
        static let headerHeight: CGFloat = 110
        static let contactsHeight: CGFloat = 134
        static let appsHeight: CGFloat = 131
        static let actionsHeight: CGFloat = 141
    }

    /// 시트만 그린다 — 딤은 ``TutorialContent`` 가 그린다(전환이 달라서 분리).
    var body: some View {
        sheet
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    private var sheet: some View {
        VStack(spacing: 0) {
            header
            separator
            contactsRow
            separator
            appsRow
            separator
            actionsRow
        }
        .frame(maxWidth: .infinity)
        // 배경만 안전영역 밖으로 늘린다 — 시트에 clipShape 를 걸면 크기가 콘텐츠에 고정돼
        // 바깥에서 ignoresSafeArea 를 걸어도 홈 인디케이터 띠가 딤인 채로 남는다.
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 10, topTrailingRadius: 10)
                .fill(Color(uiColor: .systemBackground))
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(Color(uiColor: .separator))
            .frame(height: 1)
            .padding(.horizontal, Layout.sidePadding)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            // 공유 대상 미리보기. Figma 가 시스템 공유시트에 넣어둔 이미지를 그대로 쓴다.
            Image("tutorialSharePreview", bundle: .module)
                .resizable()
                .scaledToFill()
                .frame(width: 70, height: 67)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text("Title")
                    .font(.system(size: 17))
                    .foregroundStyle(Color(uiColor: .label))
                HStack(spacing: 4) {
                    Text("people can edit.")
                        .font(.system(size: 17))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Color(uiColor: .secondaryLabel))
            }

            Spacer(minLength: 0)

            Button(action: onTapClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                    .frame(width: 30, height: 30)
                    .background(Color(uiColor: .systemGray5), in: Circle())
            }
        }
        .padding(.horizontal, Layout.sidePadding)
        .frame(height: Layout.headerHeight)
        .overlay(alignment: .top) {
            // 그래버 — Figma node 0:236 (36×5, 상단 5pt)
            Capsule()
                .fill(Color(uiColor: .systemGray3))
                .frame(width: 36, height: 5)
                .padding(.top, 5)
        }
    }

    // MARK: - Rows

    private var contactsRow: some View {
        row(height: Layout.contactsHeight) {
            contact(firstLine: "Herland", secondLine: "Antezana", isSecondLineMuted: false)
            contact(firstLine: "Rigo", secondLine: "Rangel", isSecondLineMuted: false)
            contact(firstLine: "Magico and El...", secondLine: "2 People", isSecondLineMuted: true)
            contact(firstLine: "Jenny", secondLine: "Court", isSecondLineMuted: false)
        }
    }

    private var appsRow: some View {
        row(height: Layout.appsHeight) {
            appItem(name: "우리 앱", action: onTapAppShare) {
                Image(MHIcon.send)
                    .resizable()
                    .frame(width: 34, height: 34)
                    .foregroundStyle(Color.mhStaticWhite)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.mhPrimaryNormal)
            }
            appItem(name: "Messages") {
                systemAppTile(symbol: "message.fill", tint: Color(red: 0.29, green: 0.83, blue: 0.37))
            }
            appItem(name: "Mail") {
                systemAppTile(symbol: "envelope.fill", tint: Color(red: 0.11, green: 0.51, blue: 0.95))
            }
            appItem(name: "Notes") {
                notesTile
            }
        }
    }

    private var actionsRow: some View {
        row(height: Layout.actionsHeight) {
            action(symbol: "doc.on.doc", title: "Copy")
            action(symbol: "star", title: "Add to\nFavorites")
            action(symbol: "eyeglasses", title: "Add to\nReading List")
            action(symbol: "book", title: "Add\nBookmark")
        }
    }

    /// 78pt 칸을 왼쪽부터 14pt 간격으로 늘어놓는 행.
    ///
    /// 칸 4개(24 + 78×4 + 14×3 = 402)가 화면 폭 375 를 넘어 마지막 칸이 살짝 잘린다 —
    /// 가로 스크롤되는 시스템 공유시트를 그대로 옮긴 의도된 모양이다(Figma 도 5번째 칸이 화면 밖에 있다).
    private func row<Content: View>(
        height: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: Layout.itemSpacing) {
            content()
        }
        .padding(.leading, Layout.sidePadding)
        .padding(.top, 14)
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
        .clipped()
    }

    // MARK: - Items

    private func contact(firstLine: String, secondLine: String, isSecondLineMuted: Bool) -> some View {
        VStack(spacing: 6) {
            Circle()
                .fill(Color(uiColor: .systemGray5))
                .frame(width: 60, height: 60)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(Color(uiColor: .systemGray))
                }
                .overlay(alignment: .bottomTrailing) {
                    // 공유 경로(메시지) 배지
                    Image(systemName: "message.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Color(red: 0.29, green: 0.83, blue: 0.37), in: Circle())
                        .overlay { Circle().strokeBorder(Color(uiColor: .systemBackground), lineWidth: 1.5) }
                }

            VStack(spacing: 0) {
                Text(firstLine)
                    .foregroundStyle(Color(uiColor: .label))
                Text(secondLine)
                    .foregroundStyle(isSecondLineMuted ? Color(uiColor: .secondaryLabel) : Color(uiColor: .label))
            }
            .font(.system(size: 11))
            .multilineTextAlignment(.center)
            .lineLimit(1)
        }
        .frame(width: Layout.itemWidth)
    }

    private func appItem<Tile: View>(
        name: String,
        action: @escaping () -> Void = {},
        @ViewBuilder tile: () -> Tile
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                tile()
                    .frame(width: 70, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                Text(name)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(uiColor: .label))
                    .lineLimit(1)
            }
        }
        .frame(width: Layout.itemWidth)
    }

    private func systemAppTile(symbol: String, tint: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 34))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(tint)
    }

    /// Notes 아이콘 근사 — 위쪽 노란 띠 + 흰 본문에 줄 세 개.
    private var notesTile: some View {
        VStack(spacing: 0) {
            Color(red: 1.0, green: 0.83, blue: 0.31)
                .frame(height: 16)
            VStack(spacing: 7) {
                ForEach(0..<3, id: \.self) { _ in
                    Rectangle()
                        .fill(Color(uiColor: .systemGray4))
                        .frame(height: 2)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.white)
        }
    }

    private func action(symbol: String, title: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 26))
                .foregroundStyle(Color(uiColor: .label))
                .frame(width: 60, height: 60)
                .background(Color(uiColor: .systemGray6), in: Circle())
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(Color(uiColor: .label))
                .multilineTextAlignment(.center)
        }
        .frame(width: Layout.itemWidth)
    }
}

#Preview {
    ZStack {
        Color.mhMaterialDimmer.ignoresSafeArea()
        TutorialSystemShareSheetContent()
    }
}
