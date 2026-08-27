import DesignSystem
import Domain
import SwiftUI

struct PlaceDetailCommentSection: View {
    let comments: [PlaceDetailComment]
    /// 삭제 메뉴가 열려 있는 코멘트. 목록 전체에서 하나만 열린다 — 각 코멘트가 자기 상태를 들면
    /// 여러 개가 동시에 열린다(``MHComment`` 문서 권고).
    let menuCommentID: PlaceDetailComment.ID?
    /// ⑭ 이 코멘트에 삭제 케밥을 붙일지. 내 코멘트일 때만 true 다.
    let canDelete: (PlaceDetailComment) -> Bool
    @Binding var draft: String
    /// 등록 가능한가. 내 신원을 모르면 작성자를 실을 수 없어 잠긴다.
    let canSubmit: Bool
    /// 메뉴 여닫기. nil 이면 닫기.
    let onToggleMenu: (PlaceDetailComment.ID?) -> Void
    let onDelete: (PlaceDetailComment.ID) -> Void
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

                if comments.isEmpty {
                    emptyState
                } else {
                    commentList
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

    private func commentRow(_ comment: PlaceDetailComment) -> some View {
        MHComment(
            avatar: nil,
            name: comment.author.nickname,
            comment: comment.body,
            menuItems: canDelete(comment) ? [MHMenuItem("댓글 삭제") { onDelete(comment.id) }] : [],
            menuPresented: Binding(
                get: { menuCommentID == comment.id },
                set: { onToggleMenu($0 ? comment.id : nil) }
            ),
            moreButtonLabel: "내 코멘트 더보기"
        )
        .accessibilityIdentifier("PlaceDetail.comment.\(comment.id)")
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
                MHCharacterCounter(count: draft.count, limit: PlaceDetailComment.bodyLimit)
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
                menuCommentID: nil,
                canDelete: { _ in false },
                draft: $draft,
                canSubmit: true,
                onToggleMenu: { _ in },
                onDelete: { _ in },
                onSubmit: {}
            )
        }
    }
    return Host()
}

#Preview("코멘트 있음 — 내 것에만 케밥") {
    struct Host: View {
        @State private var draft = ""
        @State private var comments = PlaceDetailComment.samples
        @State private var menuCommentID: PlaceDetailComment.ID?
        private let me = MemberID("user-0001")

        var body: some View {
            ScrollView {
                PlaceDetailCommentSection(
                    comments: comments,
                    menuCommentID: menuCommentID,
                    canDelete: { $0.isWritten(by: me) },
                    draft: $draft,
                    canSubmit: true,
                    onToggleMenu: { menuCommentID = $0 },
                    onDelete: { id in
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
