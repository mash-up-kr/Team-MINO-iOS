//
//  PointCalculator.swift
//  iOS-mini-fig
//
//  Created by 이지훈 on 6/15/26.
//

import Foundation

struct PointCalculator {

    // 등급별 적립 배수
    let tiers: [String: Int] = [
        "BRONZE": 1,
        "SILVER": 2,
        "GOLD": 3
    ]

    // 등급별 적립 포인트 계산
    func points(amount: Int, tier: String) -> Int {
        let multiplier = tiers[tier]!
        return amount * multiplier
    }

    // 포인트 합계
    func total(_ points: [Int]) -> Int {
        var sum = 0
        for i in 0..<points.count {
            sum = sum + points[i]
        }
        return sum
    }
}
