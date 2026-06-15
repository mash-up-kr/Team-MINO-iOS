import UIKit
import Domain
import DesignSystem

/// UseCase 와 DesignSystem 만 사용하는 화면.
/// Data/Networking 같은 인프라 계층은 알지 못하며, Repository 구현은 외부에서 주입된다.
public final class MemberViewController: UIViewController {
    private let useCase: FetchMemberUseCase
    private let memberID: MemberID

    private let titleLabel = TitleLabel(text: "불러오는 중…")

    public init(useCase: FetchMemberUseCase, memberID: MemberID) {
        self.useCase = useCase
        self.memberID = memberID
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColors.background
        setupLayout()
        load()
    }

    private func setupLayout() {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
        ])
    }

    private func load() {
        Task {
            do {
                let member = try await useCase.execute(id: memberID)
                titleLabel.text = "안녕하세요, \(member.name)님"
            } catch {
                titleLabel.text = "회원 정보를 불러오지 못했어요"
            }
        }
    }
}
