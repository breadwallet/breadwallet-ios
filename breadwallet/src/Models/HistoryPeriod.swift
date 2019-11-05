//
//  HistoryPeriod.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2019-07-11.
//  Copyright © 2019 breadwallet LLC. All rights reserved.
//

import Foundation

enum HistoryPeriod: String, CaseIterable {
    case day
    case week
    case month
    case months
    case year
    case years
    
    static var defaultPeriod: HistoryPeriod {
        guard let saved = UserDefaults.lastChartHistoryPeriod, let period = HistoryPeriod(rawValue: saved) else {
            return .year
        }
        return period
    }
    
    func saveMostRecent() {
        UserDefaults.lastChartHistoryPeriod = self.rawValue
    }
    
    //DateComponentsFormatter uses 'mo' as a month abbreviation due to collision with minutes.
    //The trailing o is removed to keep the headering looking clean
    //DateComponentsFormatter also inserts a space between the number and unit, which is also trimmed out
    var buttonLabel: String {
        switch self {
        case .day:
            return (formatterForUnits([.day]).string(from: 60*60*24) ?? "1d").trim(" ").toMaxLength(2)
        case .week:
            return (formatterForUnits([.weekOfMonth]).string(from: 60*60*24*7) ?? "1w").trim(" ").toMaxLength(2)
        case .month:
            return (formatterForUnits([.month]).string(from: 60*60*24*31) ?? "1m").trim(" ").toMaxLength(2)
        case .months:
            return (formatterForUnits([.month]).string(from: 60*60*24*31*3) ?? "3m").trim(" ").toMaxLength(2)
        case .year:
            return (formatterForUnits([.year]).string(from: 60*60*24*31*12) ?? "1y").trim(" ").toMaxLength(2)
        case .years:
            return (formatterForUnits([.year]).string(from: 60*60*24*31*36) ?? "3y").trim(" ").toMaxLength(2)
        }
    }
    
    func urlForCode(code: String) -> URL {
        let tsym = Store.state.defaultCurrencyCode.uppercased()
        switch self {
        case .day:
            return URL(string: "https://min-api.cryptocompare.com/data/histominute?fsym=\(code.uppercased())&tsym=\(tsym)&limit=1440")!
        case .week:
            return URL(string: "https://min-api.cryptocompare.com/data/histohour?fsym=\(code.uppercased())&tsym=\(tsym)&limit=168")!
        case .month:
            return URL(string: "https://min-api.cryptocompare.com/data/histohour?fsym=\(code.uppercased())&tsym=\(tsym)&limit=720")!
        case .months:
            return URL(string: "https://min-api.cryptocompare.com/data/histoday?fsym=\(code.uppercased())&tsym=\(tsym)&limit=90")!
        case .year:
            return URL(string: "https://min-api.cryptocompare.com/data/histoday?fsym=\(code.uppercased())&tsym=\(tsym)&limit=365")!
        case .years:
            return URL(string: "https://min-api.cryptocompare.com/data/histoday?fsym=\(code.uppercased())&tsym=\(tsym)&limit=1095")!
        }
    }
    
    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        switch self {
        case .day, .week:
            formatter.setLocalizedDateFormatFromTemplate("HH:mm MMM d")
        case .month, .months, .year, .years:
            formatter.setLocalizedDateFormatFromTemplate("MMM d, ''yy")
        }
        
        return formatter
    }
    
    // Minute, hour and day history endpoints have varying numbers of
    // datapoints. The reductionFactor is used to throw away extra points
    // so that all charts have a similar number of data points.
    //
    // eg. a reduction factor of 6 would reduce an array of size
    // 1095 to 1095/6=182
    //
    // A reductionFactor of 0 has no effect
    var reductionFactor: Int {
        switch self {
        case .day:
            return 8
        case .month:
            return 4
        case .year:
            return 2
        case .years:
            return 5
        default:
            return 0
        }
    }
}

private func formatterForUnits(_ units: NSCalendar.Unit) -> DateComponentsFormatter {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = units
    formatter.unitsStyle = .abbreviated
    return formatter
}
