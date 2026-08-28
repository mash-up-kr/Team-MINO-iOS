import DesignSystem
import Domain
import SwiftUI

struct PlaceDetailCommentSection: View {
    let comments: [PinComment]
    /// "아직 코멘트가 없어요" 를 띄울 때인가. 조회가 끝나고 정말 비었을 때만 true 다 —
    /// 목록이 비어 있다는 것만으로 그리면 조회 전에 잠깐 스친다.
    let showsEmptyState: Bool
    /// 삭제 메뉴가 열려 있는 코멘트. 목록 전체에서 하나만 열린다 — 각 코멘트가 자기 상태를 들면
    /// 여러 개가 동시에 열린다(``MHComment`` 문서 권고).
    let menuCommentID: PinCommentID?
    /// ⑭ 이 코멘트에 삭제 케밥을 붙일지. 내 코멘트일 때만 true 다.
    let canDelete: (PinComment) -> Bool
    @Binding var draft: String
    /// 등록 가능한가. 내 신원을 모르거나 보낸 요청이 아직 안 돌아왔으면 잠긴다.
    let canSubmit: Bool
    /// 메뉴 여닫기. nil 이면 닫기.
    let onToggleMenu: (PinCommentID?) -> Void
    /// 삭제 **요청**. 실제 삭제는 확인 다이얼로그를 거친 뒤라 이 자리에서 일어나지 않는다(⑭).
    let onRequestDelete: (PinCommentID) -> Void
    let onSubmit: () -> Void

    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 30) {
                Text("친구들의 코멘트")
                    .mhTypography(.headline1Bold)
                    .foregroundStyle(.mhLabelNormal)

                if !comments.isEmpty {
                    commentList
                } else if showsEmptyState {
                    emptyState
                }

                input
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            submitRow
        }
    }

    private var commentList: some View {
        // LazyVStack 은 자식의 zIndex 를 무시해 아래 코멘트가 열린 메뉴 위로 그려진다.
        VStack(spacing: 20) {
            ForEach(Array(comments.enumerated()), id: \.element.id) { index, comment in
                VStack(spacing: 20) {
                    if index > 0 {
                        Rectangle()
                            .fill(.mhLineNormalNormal)
                            .frame(height: 1)
                    }
                    commentRow(comment)
                }
                .zIndex(menuCommentID == comment.id ? 1 : 0)
            }
        }
        .accessibilityIdentifier("PlaceDetail.commentList")
    }

    private func commentRow(_ comment: PinComment) -> some View {
        MHComment(
            avatar: ArchiveAvatarArt.image(for: comment.author.avatarID),
            name: comment.author.nickname,
            comment: comment.body,
            menuItems: canDelete(comment) ? [MHMenuItem("댓글 삭제") { onRequestDelete(comment.id) }] : [],
            menuPresented: Binding(
                get: { menuCommentID == comment.id },
                set: { onToggleMenu($0 ? comment.id : nil) }
            ),
            moreButtonLabel: "내 코멘트 더보기"
        )
        .accessibilityIdentifier("PlaceDetail.comment.\(comment.id.value)")
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Image("emptyCommentIllustration", bundle: .module)
                .resizable()
                .scaledToFit()
                .frame(width: 220)
                .accessibilityHidden(true)

            Text("아직 코멘트가 없어요!")
                .mhTypography(.body1ReadingRegular)
                .foregroundStyle(.mhLabelAlternative)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 20)
        .accessibilityIdentifier("PlaceDetail.commentEmptyState")
    }

    private var input: some View {
        MHTextArea(
            "코멘트를 입력해 보세요.",
            text: $draft,
            identifier: "PlaceDetail.commentInput",
            bottomLeading: {
                MHCharacterCounter(count: draft.count, limit: PinComment.bodyLimit)
            }
        )
    }

    private var submitRow: some View {
        MHButton("등록", size: .large, action: onSubmit)
            .disabled(trimmedDraft.isEmpty || !canSubmit)
            .accessibilityIdentifier("PlaceDetail.submitComment")
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(20)
    }
}

#Preview("코멘트 없음") {
    struct Host: View {
        @State private var draft = ""
        var body: some View {
            PlaceDetailCommentSection(
                comments: [],
                showsEmptyState: true,
                menuCommentID: nil,
                canDelete: { _ in false },
                draft: $draft,
                canSubmit: true,
                onToggleMenu: { _ in },
                onRequestDelete: { _ in },
                onSubmit: {}
            )
        }
    }
    return Host()
}

#Preview("코멘트 있음 — 내 것에만 케밥") {
    struct Host: View {
        @State private var draft = ""
        @State private var comments = PinComment.placeDetailSamples
        @State private var menuCommentID: PinCommentID?
        private let me = MemberID("user-0001")

        var body: some View {
            ScrollView {
                PlaceDetailCommentSection(
                    comments: comments,
                    showsEmptyState: true,
                    menuCommentID: menuCommentID,
                    canDelete: { $0.isWritten(by: me) },
                    draft: $draft,
                    canSubmit: true,
                    onToggleMenu: { menuCommentID = $0 },
                    // 앱에서는 확인 다이얼로그를 거치지만(⑭) 그 다이얼로그는 화면 쪽에 있다 —
                    // 여기선 섹션만 보는 프리뷰라 바로 지운다.
                    onRequestDelete: { id in
                        menuCommentID = nil
                        comments.removeAll { $0.id == id }
                    },
                    onSubmit: {}
                )
            }
        }
    }
    return Host()
}
