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

// MARK: - Weight Entry

struct WeightEntry: Identifiable {
    let id: Int64
    let date: String
    let weight: Double  // lbs
    var dateValue: Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: date) ?? Date()
    }
}

// MARK: - Adaptive TDEE

struct AdaptiveTDEE {
    /// Calculate actual TDEE from weight trend + calorie intake over the last N days.
    /// Uses the energy-balance equation:
    ///   Actual TDEE = Avg Daily Calories  -  (Weight Change in lbs × 3500) / days
    /// where 3500 kcal ≈ 1 lb of body weight.
    /// Returns nil if insufficient data (need ≥ 2 weight entries spanning ≥ 7 days).
    static func calculate(weights: [WeightEntry], dailyCalories: [DayCalories]) -> Int? {
        guard weights.count >= 2 else { return nil }

        let sorted = weights.sorted { $0.date < $1.date }
        guard let first = sorted.first, let last = sorted.last,
              first.date != last.date else { return nil }

        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let startDate = f.date(from: first.date),
              let endDate = f.date(from: last.date) else { return nil }

        let daySpan = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        guard daySpan >= 7 else { return nil }

        // Use 7-day smoothed averages to reduce daily noise
        let firstWeekWeights = Array(sorted.prefix(min(7, sorted.count)))
        let lastWeekWeights  = Array(sorted.suffix(min(7, sorted.count)))
        let avgStartWeight = firstWeekWeights.map(\.weight).reduce(0, +) / Double(firstWeekWeights.count)
        let avgEndWeight   = lastWeekWeights.map(\.weight).reduce(0, +) / Double(lastWeekWeights.count)

        let weightChangeLbs = avgEndWeight - avgStartWeight  // positive = gained

        // Average daily calories over the period
        let calDates = Set(dailyCalories.map(\.date))
        let relevantCals = dailyCalories.filter { $0.date >= first.date && $0.date <= last.date }
        let totalCals = relevantCals.map(\.calories).reduce(0, +)
        let daysWithData = max(1, relevantCals.count)
        let avgDailyCals = Double(totalCals) / Double(daysWithData)

        // Energy balance: TDEE = intake - surplus
        // surplus = (weightChange × 3500) / days
        let dailySurplus = (weightChangeLbs * 3500.0) / Double(daySpan)
        let actualTDEE = avgDailyCals - dailySurplus

        return max(1200, Int(actualTDEE.rounded()))  // floor at 1200 for safety
    }

    /// Suggest a new calorie goal given actual TDEE and the user's weight plan.
    /// Same offsets as GoalRow: gain +500, lose -500, maintain 0, etc.
    static func suggestedGoal(actualTDEE: Int, weightPlan: String) -> Int {
        let offset: Int
        switch weightPlan {
        case "gain":  offset = 500
        case "lose":  offset = -500
        default:      offset = 0
        }
        return max(1200, actualTDEE + offset)
    }
}
