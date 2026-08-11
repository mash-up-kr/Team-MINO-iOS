import SwiftUI

/// 방 목록 한 줄. Figma `Card_Room`(showMemo / showListCell, node 15852:88349).
///
/// 왼쪽에 방 썸네일(``MHRoomThumbnail``), 가운데에 방 이름 + (선택) 메모 + "장소 N개", 오른쪽에 멤버
/// 아바타 그룹(``MHAvatarGroup``)을 둔다. `selection` 바인딩을 주면 **선택 모드**가 되어 아바타 그룹 대신
/// 오른쪽 끝에 체크박스(``MHCheckbox``)가 뜬다(목록 다중 선택).
///
/// ```swift
/// MHRoomCard(title: "내 방", memo: "내가 꾹 저장한 장소", placeCount: 0, members: [img])
/// MHRoomCard(title: "내 방", placeCount: 3, selection: $picked)     // 선택 모드(체크박스)
/// MHRoomCard(title: "내 방", placeCount: 0, thumbnail: .myRoom)     // my-room 전용 일러스트 썸네일
/// ```
public struct MHRoomCard: View {
    private let title: String
    private let memo: String?
    private let placeCount: Int
    private let thumbnail: MHRoomThumbnailKind
    private let members: [Image?]
    private let selection: Binding<Bool>?

    public init(
        title: String,
        memo: String? = nil,
        placeCount: Int,
        thumbnail: MHRoomThumbnailKind = .color(.pink),
        members: [Image?] = [],
        selection: Binding<Bool>? = nil
    ) {
        self.title = title
        self.memo = memo
        self.placeCount = placeCount
        self.thumbnail = thumbnail
        self.members = members
        self.selection = selection
    }

    public var body: some View {
        HStack(spacing: 12) {
            MHRoomThumbnail(kind: thumbnail, size: 80)
            VStack(alignment: .leading, spacing: 8) {
                titleBlock
                bottom
            }
            if let selection {
                MHCheckbox(isOn: selection)
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // 메모 유무와 무관하게 행 높이 46 고정.
    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            line(title, .body1NormalBold, .mhLabelNormal)
            if let memo {
                line(memo, .label2Medium, .mhLabelAlternative)
            }
        }
        .frame(height: 46, alignment: .top)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bottom: some View {
        HStack(alignment: .bottom, spacing: 4) {
            Text("장소 \(placeCount)개")
                .lineLimit(1)
                .foregroundStyle(.mhLabelAlternative)
                .mhTypography(.label2Bold)
                .frame(maxWidth: .infinity, alignment: .leading)
            if selection == nil, !members.isEmpty {
                MHAvatarGroup(members, variant: .person, size: .xSmall)
            }
        }
    }

    private func line(_ string: String, _ token: MHTypography, _ color: Color) -> some View {
        Text(string)
            .lineLimit(1)
            .truncationMode(.tail)
            .foregroundStyle(color)
            .mhTypography(token)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("MHRoomCard") {
    struct Host: View {
        @State private var picked = true
        var body: some View {
            VStack(spacing: 0) {
                MHRoomCard(title: "내 방", memo: "내가 꾹 저장한 장소", placeCount: 0, members: [nil])
                MHRoomCard(title: "내 방", placeCount: 0, members: [nil])
                MHRoomCard(title: "내 방", placeCount: 0, selection: $picked)
                MHRoomCard(title: "내 방", memo: "내가 꾹 저장한 장소", placeCount: 0, selection: $picked)
                MHRoomCard(title: "내 장소", placeCount: 0, thumbnail: .myRoom, members: [nil])
            }
            .frame(width: 375)
            .padding()
        }
    }
    return Host()
}
