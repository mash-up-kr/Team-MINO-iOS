import DesignSystem
import SwiftUI

/// 코멘트 목록(없으면 빈 상태)과 입력·등록 영역.
struct PlaceDetailCommentSection: View {
    let comments: [PlaceDetailComment]
    @Binding var draft: String
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
                MHComment(avatar: nil, name: comment.author, comment: comment.body)
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

    // `MHActionArea` 는 주 버튼을 전체 폭으로 그려 시안(우측 hug)과 어긋난다 — 버튼만 가져다 쓴다.
    private var submitRow: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            MHButton("등록", size: .large, action: onSubmit)
                .disabled(trimmedDraft.isEmpty)
                .accessibilityIdentifier("PlaceDetail.submitComment")
        }
        .padding(20)
    }
}

#Preview("코멘트 없음") {
    struct Host: View {
        @State private var draft = ""
        var body: some View {
            PlaceDetailCommentSection(comments: [], draft: $draft, onSubmit: {})
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
                    comments: PlaceDetailComment.samples, draft: $draft, onSubmit: {}
                )
            }
        }
    }
    return Host()
}
