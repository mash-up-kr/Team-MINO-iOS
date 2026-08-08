import XCTest
import SwiftUI
@testable import DesignSystem

/// PR 첨부용 디바이스 스크린샷 생성 테스트.
/// `/tmp/pr_screenshots/` 에 iPhone 16 크기(393pt, @3x) PNG 를 저장한다.
final class PRScreenshotTests: XCTestCase {
    private let dir = "/tmp/pr_screenshots"
    private let w: CGFloat = 393

    override func setUp() {
        super.setUp()
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        MHFontRegistrar.registerIfNeeded()
    }

    // MARK: - 이번 브랜치 신규 컴포넌트

    @MainActor func testRoomThumbnailEmpty() throws {
        try snap("room_thumbnail_empty") {
            screen {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(70), spacing: 10), count: 4), spacing: 10) {
                    ForEach(MHRoomThumbnailColor.allCases, id: \.self) { MHRoomThumbnail(color: $0, size: 70) }
                    MHRoomThumbnail.myRoom(size: 70)
                }
            }
        }
    }

    @MainActor func testRoomThumbnailFull() throws {
        let photo = Image(systemName: "photo")
        try snap("room_thumbnail_full") {
            screen {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(70), spacing: 10), count: 4), spacing: 10) {
                    MHRoomThumbnail(images: [photo], size: 70)
                    MHRoomThumbnail(images: [photo, photo], size: 70)
                    MHRoomThumbnail(images: [photo, photo, photo], size: 70)
                    MHRoomThumbnail(images: [photo, photo, photo, photo], size: 70)
                }
            }
        }
    }

    @MainActor func testInvitationCard() throws {
        try snap("invitation_card") {
            screen {
                VStack(spacing: 16) {
                    MHInvitationCard(thumbnailColor: .pink, title: "5월의 약속 : 우리끼리", description: "우리 모임 장소 픽업 공간.", members: [nil, nil, nil], placeCount: 1200).frame(width: 260)
                    MHInvitationCard(thumbnailColor: .violet, title: "5월의 약속 : 우리끼리", description: "우리 모임 장소 픽업 공간.", members: [nil, nil, nil, nil, nil, nil, nil], placeCount: 5).frame(width: 200)
                }
            }
        }
    }

    @MainActor func testInvitation() throws {
        try snap("invitation") {
            screen {
                MHInvitation(thumbnailColor: .pink, title: "5월의 약속 : 우리끼리", description: "우리 모임 장소 픽업 공간.", members: [nil, nil, nil], placeCount: 1200)
            }
        }
    }

    @MainActor func testTabBar() throws {
        try snap("tab_bar") {
            VStack {
                Spacer()
                MHTabBar(items: [
                    MHTabBarItem(id: 0, icon: .homeFill, label: "홈"),
                    MHTabBarItem(id: 1, icon: .folderFill, label: "저장"),
                    MHTabBarItem(id: 2, icon: .bellFill, label: "알림"),
                    MHTabBarItem(id: 3, icon: .personCircleFill, label: "마이페이지"),
                ], selectedID: .constant(0))
            }.frame(width: w, height: 200).background(Color.white)
        }
    }

    // MARK: - 기존 컴포넌트

    @MainActor func testRoomCard() throws {
        try snap("room_card") {
            screen {
                VStack(spacing: 0) {
                    MHRoomCard(title: "내 방", memo: "내가 꾹 저장한 장소", placeCount: 0, members: [nil])
                    MHRoomCard(title: "내 방", placeCount: 0, members: [nil])
                    MHRoomCard(title: "내 방", placeCount: 0, selection: .constant(false))
                    MHRoomCard(title: "내 방", memo: "내가 꾹 저장한 장소", placeCount: 0, selection: .constant(false))
                }.frame(width: 375)
            }
        }
    }

    @MainActor func testLocationCard() throws {
        try snap("location_card") {
            screen {
                VStack(alignment: .leading, spacing: 8) {
                    MHLocationCard(title: "레이어스튜디오 10", address: "서울 성동구 상원4길 10", commentCount: 1200, members: [nil, nil])
                    MHLocationCard(title: "레이어스튜디오 10", address: "서울 성동구 상원4길 10", commentCount: 8)
                    MHLocationCard(title: "레이어스튜디오 10", address: "서울 성동구 상원4길 10", commentCount: 8, members: [nil], layout: .expanded)
                }.frame(width: 335)
            }
        }
    }

    @MainActor func testHomeCard() throws {
        try snap("home_card") {
            screen {
                VStack(spacing: 16) {
                    homeCard(.mhAccentForegroundLightBlue, "친구들이 많이 본 곳")
                    homeCard(.mhAccentForegroundPink, "이야기 많은 곳")
                }.frame(width: 335)
            }
        }
    }

    @MainActor func testComment() throws {
        let unit = "친구가 남긴 코멘트입니다."
        try snap("comment") {
            screen {
                VStack(alignment: .leading, spacing: 20) {
                    MHComment(avatar: nil, name: "이름", comment: unit)
                    MHComment(avatar: nil, name: "이름", comment: String(repeating: unit, count: 7))
                }.frame(width: 335)
            }
        }
    }

    @MainActor func testChip() throws {
        try snap("chip") {
            screen {
                VStack(alignment: .leading, spacing: 16) {
                    chipRow(.solid, active: false)
                    chipRow(.solid, active: true)
                    chipRow(.outlined, active: false)
                    chipRow(.outlined, active: true)
                }
            }
        }
    }

    @MainActor func testFilterBar() throws {
        try snap("filter_bar") {
            screen {
                VStack(alignment: .leading, spacing: 24) {
                    MHFilterBar(sortOptions: ["거리순", "최신순"], selectedSort: .constant(0),
                                categories: ["전체", "카페", "맛집", "술집", "놀거리"], selectedCategory: .constant(0))
                    // 메뉴 열린 상태는 내부 @State 라 ImageRenderer 로 캡처 불가 — Xcode 프리뷰 참고
                }.frame(width: 375)
            }
        }
    }

    @MainActor func testRoomHeader() throws {
        try snap("room_header") {
            screen {
                VStack(spacing: 30) {
                    MHRoomHeader(title: "Title", memo: "memo", count: "999+개") { }
                    MHRoomHeader(title: "Title", count: "999+개") { }
                }.frame(width: 375)
            }
        }
    }

    @MainActor func testAvatarStack() throws {
        try snap("avatar_stack") {
            screen {
                VStack(alignment: .leading, spacing: 20) {
                    MHAvatarStack([Image?.none]) { }
                    MHAvatarStack(Array(repeating: Image?.none, count: 4))
                    MHAvatarStack(Array(repeating: Image?.none, count: 3), trailing: .overflow(99))
                    HStack(spacing: 16) {
                        MHAvatarStack(Array(repeating: Image?.none, count: 2), trailing: .overflow(5))
                        MHAvatarStack(Array(repeating: Image?.none, count: 3), trailing: .overflow(12))
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    @MainActor
    private func screen<C: View>(@ViewBuilder content: () -> C) -> some View {
        content()
            .padding(24)
            .frame(width: w)
            .background(Color.white)
    }

    @MainActor
    private func snap<V: View>(_ name: String, @ViewBuilder content: () -> V) throws {
        let renderer = ImageRenderer(content: content())
        renderer.scale = 3
        let img = try XCTUnwrap(renderer.uiImage, "\(name) 렌더 실패")
        let data = try XCTUnwrap(img.pngData())
        try data.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
        print("SCREENSHOT_SAVED: \(dir)/\(name).png")
    }

    @MainActor
    private func homeCard(_ color: Color, _ text: String) -> MHHomeCard {
        MHHomeCard(avatar: nil, badgeText: text, badgeColor: color,
                   title: "레이어스튜디오 10", address: "서울 성동구 상원4길 10",
                   images: [solidImage(.systemGray3), solidImage(.systemGray4)]) { }
    }

    private func solidImage(_ color: UIColor) -> Image {
        let s = CGSize(width: 120, height: 150)
        return Image(uiImage: UIGraphicsImageRenderer(size: s).image { ctx in
            color.setFill(); ctx.fill(CGRect(origin: .zero, size: s))
        })
    }

    @MainActor
    private func chipRow(_ variant: MHChipVariant, active: Bool) -> some View {
        HStack(spacing: 10) {
            ForEach([MHChipSize.xsmall, .small, .medium, .large], id: \.self) { size in
                MHChip("텍스트", variant: variant, size: size, isActive: active) {}
            }
        }
    }
}
