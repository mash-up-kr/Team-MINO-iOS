import UIKit

/// 디자인 시스템 토큰이 적용된 재사용 가능한 타이틀 라벨.
public final class TitleLabel: UILabel {
    public init(text: String) {
        super.init(frame: .zero)
        self.text = text
        self.font = AppTypography.title
        self.textColor = AppColors.textPrimary
        self.numberOfLines = 0
        self.textAlignment = .center
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
