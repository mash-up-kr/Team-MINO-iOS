import DesignSystem
import SwiftUI

struct PlaceDetailPhotoCarousel: View {
    let count: Int

    private static let side: CGFloat = 240
    private static let cornerRadius: CGFloat = 21.5

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<max(count, 1), id: \.self) { index in
                    placeholder
                        .accessibilityIdentifier("PlaceDetail.photo.\(index)")
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .accessibilityIdentifier("PlaceDetail.photos")
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
            .fill(.mhFillNormal)
            .frame(width: Self.side, height: Self.side)
            .overlay {
                Image(systemName: "photo")
                    .font(.system(size: 44))
                    .foregroundStyle(.mhLabelDisable)
            }
            .overlay {
                RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                    .strokeBorder(.mhLineNormalAlternative, lineWidth: 1)
            }
    }
}

#Preview {
    PlaceDetailPhotoCarousel(count: 2)
}
