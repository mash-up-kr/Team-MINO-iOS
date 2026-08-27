import DesignSystem
import SwiftUI

struct PlaceDetailCommentSection: View {
    let comments: [PlaceDetailComment]
    @Binding var draft: String
    /// 등록 가능한가. 내 신원을 모르면 작성자를 실을 수 없어 잠긴다.
    let canSubmit: Bool
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
        VStack(spacing: 20) {
            ForEach(Array(comments.enumerated()), id: \.element.id) { index, comment in
                if index > 0 {
                    Rectangle()
                        .fill(.mhLineNormalNormal)
                        .frame(height: 1)
                }
                MHComment(avatar: nil, name: comment.author.nickname, comment: comment.body)
            }
        }
        .accessibilityIdentifier("PlaceDetail.commentList")
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
            PlaceDetailCommentSection(comments: [], draft: $draft, canSubmit: true, onSubmit: {})
        }
    }
    return Host()
}

#Preview("코멘트 있음") {
    struct Host: View {
        @State private var draft = ""
        var body: some View {
            ScrollView {
                PlaceDetailCommentSection(
                    comments: PlaceDetailComment.samples, draft: $draft, canSubmit: true, onSubmit: {}
                )
            }
        }
    }
    return Host()
}
