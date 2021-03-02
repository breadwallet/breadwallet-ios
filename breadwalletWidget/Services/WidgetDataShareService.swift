// 
//  WidgetDataShareService.swift
//  breadwallet
//
//  Created by stringcode on 21/02/2021.
//  Copyright © 2021 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import Foundation

protocol WidgetDataShareService: class {

    var sharingEnabled: Bool {get set}
    var quoteCurrencyCode: String? {get set}
    func updatePortfolio(info: [CurrencyId: Double])
    func amount(for currencyId: CurrencyId) -> Double?
}

// MARK: - DefaultWidgetDataShareService

class DefaultWidgetDataShareService: WidgetDataShareService {

    var sharingEnabled: Bool {
        get {
            defaults().bool(forKey: Constant.sharePortfolioKey)
        }
        set {
            defaults().set(newValue, forKey: Constant.sharePortfolioKey)

            if !newValue {
                defaults().setValue(nil, forKey: Constant.portfolioInfoKey)
            }

            defaults().synchronize()
        }
    }

    var quoteCurrencyCode: String? {
        get {
            defaults().string(forKey: Constant.quoteCurrencyCodeKey)
        }
        set {
            defaults().set(newValue, forKey: Constant.quoteCurrencyCodeKey)
            defaults().synchronize()
        }
    }

    func updatePortfolio(info: [CurrencyId: Double]) {
        let stringInfo = info.map { ($0.rawValue, $1) }
            .reduce(into: [String: Double]()) { $0[$1.0] = $1.1 }
        defaults().setValue(stringInfo, forKey: Constant.portfolioInfoKey)
        defaults().synchronize()
    }

    func amount(for currencyId: CurrencyId) -> Double? {
        guard sharingEnabled else {
            return nil
        }

        guard let info = defaults().value(forKey: Constant.portfolioInfoKey) else {
            return nil
        }

        return (info as? [String: Double])?[currencyId.rawValue]
    }

    private func defaults() -> UserDefaults {
        return Constant.defaults
    }
}

// MARK: - Constant

extension DefaultWidgetDataShareService {

    enum Constant {
        static let portfolioInfoKey = "PortfolioInfo"
        static let sharePortfolioKey = "SharePortfolio"
        static let quoteCurrencyCodeKey = "QuoteCurrencyCode"
        static let appGroupsId = Bundle.main.object(forInfoDictionaryKey: "APP_GROUPS_ID") as? String
        static let defaults = UserDefaults(suiteName: appGroupsId ?? "fail")!
    }
}
