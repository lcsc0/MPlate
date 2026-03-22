//
//  TrendModels.swift
//  MPlate
//

import Foundation

enum TrendPeriod: String, CaseIterable {
    case oneWeek = "1W"
    case oneMonth = "1M"
    case threeMonths = "3M"
    case sixMonths = "6M"
    case oneYear = "1Y"

    var days: Int {
        switch self {
        case .oneWeek:     return 7
        case .oneMonth:    return 30
        case .threeMonths: return 90
        case .sixMonths:   return 180
        case .oneYear:     return 365
        }
    }
}

struct DayCalories: Identifiable {
    let id = UUID()
    let date: String
    let calories: Int
    var dateValue: Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: date) ?? Date()
    }
}
