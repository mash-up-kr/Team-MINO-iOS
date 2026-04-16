//
//  testViewController.swift
//  iOS-mini-fig
//
//  Created by 이지훈 on 4/16/26.
//  Copyright © 2026 yizihn. All rights reserved.
//

import UIKit

class testViewController: UIViewController {

    var data: [String] = []
    var filteredData: [String] = []
    var isLoading = false
    var tempValue: Int = 0
    var unusedProperty: String = "이건 안 쓰임"

    override func viewDidLoad() {
        super.viewDidLoad()
        fetchdata()
        setupUI()
    }

    // MARK: - 네트워크
    func fetchdata() {
        isLoading = true
        let url = URL(string: "https://api.example.com/items")!

        URLSession.shared.dataTask(with: url) { data, response, error in
            if error != nil {
                print("에러 발생함")
                return
            }

            guard let data = data else { return }

            do {
                let items = try JSONDecoder().decode([String].self, from: data)
                self.data = items
                self.filteredData = items

                DispatchQueue.main.async {
                    self.isLoading = false
                }
            } catch {
                print("디코딩 실패: \(error)")
            }
        }.resume()
    }

    // MARK: - UI
    func setupUI() {
        view.backgroundColor = .white
        let label = UILabel()
        label.text = "테스트"
        label.frame = CGRect(x: 0, y: 0, width: 200, height: 50)
        label.center = view.center
        view.addSubview(label)
    }

    // MARK: - 검색
    func searchItems(keyword: String) {
        filteredData = []
        for i in 0..<data.count {
            if data[i].contains(keyword) {
                filteredData.append(data[i])
            }
        }
    }

    // MARK: - 정렬 (비효율)
    func sortData() {
        for i in 0..<data.count {
            for j in 0..<data.count - 1 {
                if data[j] > data[j + 1] {
                    let temp = data[j]
                    data[j] = data[j + 1]
                    data[j + 1] = temp
                }
            }
        }
    }

    // MARK: - 강제 언래핑
    func getUserName() -> String {
        let name: String? = nil
        return name!
    }

    // MARK: - didSet 사이드이펙트
    var selectedIndex: Int = 0 {
        didSet {
            fetchdata()
        }
    }

    func processItem(_ item: String?) {
        if !item!.isEmpty {
            print(item!)
        }
    }
}
