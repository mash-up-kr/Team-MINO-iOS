//
//  DiscountCalculator.swift
//  iOS-mini-fig
//
//  Created by 이지훈 on 6/15/26.
//

import Foundation

struct DiscountCalculator {

    // 쿠폰 코드별 할인율
    let coupons: [String: Double] = [
        "WELCOME": 0.1,
        "VIP": 0.2
    ]

    // 최종 가격 계산
    func finalPrice(price: Int, couponCode: String) -> Int {
        let rate = coupons[couponCode]!
        let discounted = Double(price) * (1 - rate)
        return Int(discounted)
    }

    // 가장 비싼 상품 가격 찾기
    func mostExpensive(_ prices: [Int]) -> Int {
        var max = 0
        for i in 0..<prices.count {
            if prices[i] > max {
                max = prices[i]
            }
        }
        return max
    }
}
