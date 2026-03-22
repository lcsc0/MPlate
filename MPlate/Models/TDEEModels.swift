//
//  TDEEModels.swift
//  MPlate
//

import SwiftUI

// MARK: - Activity Level

enum ActivityLevel: String, CaseIterable, Identifiable {
    case sedentary   = "Sedentary"
    case light       = "Light"
    case moderate    = "Moderate"
    case active      = "Active"
    case extraActive = "Extra Active"

    var id: String { rawValue }

    var factor: Double {
        switch self {
        case .sedentary:   return 1.2
        case .light:       return 1.375
        case .moderate:    return 1.55
        case .active:      return 1.725
        case .extraActive: return 1.9
        }
    }

    var description: String {
        switch self {
        case .sedentary:   return "Little or no exercise, desk job"
        case .light:       return "Light exercise 1-3 days/week"
        case .moderate:    return "Moderate exercise 3-5 days/week"
        case .active:      return "Hard exercise 6-7 days/week"
        case .extraActive: return "Very hard exercise or physical job"
        }
    }
}

// MARK: - Goal Row Model

struct GoalRow: Identifiable {
    let id = UUID()
    let label: String
    let subtitle: String
    let offset: Int
    let weightPlan: String

    static let all: [GoalRow] = [
        GoalRow(label: "Extreme Weight Gain", subtitle: "+2 lb / week",   offset: +1000, weightPlan: "gain"),
        GoalRow(label: "Weight Gain",         subtitle: "+1 lb / week",   offset:  +500, weightPlan: "gain"),
        GoalRow(label: "Mild Weight Gain",    subtitle: "+0.5 lb / week", offset:  +250, weightPlan: "gain"),
        GoalRow(label: "Maintain Weight",     subtitle: "0 lb / week",    offset:     0, weightPlan: "maintain"),
        GoalRow(label: "Mild Weight Loss",    subtitle: "-0.5 lb / week", offset:  -250, weightPlan: "lose"),
        GoalRow(label: "Weight Loss",         subtitle: "-1 lb / week",   offset:  -500, weightPlan: "lose"),
        GoalRow(label: "Extreme Weight Loss", subtitle: "-2 lb / week",   offset: -1000, weightPlan: "lose"),
    ]

    var rowColor: Color {
        switch weightPlan {
        case "gain":
            switch offset {
            case 1000: return Color.mBlue.opacity(0.90)
            case 500:  return Color.mBlue.opacity(0.65)
            default:   return Color.mBlue.opacity(0.40)
            }
        case "lose":
            switch offset {
            case -1000: return Color(red: 0.05, green: 0.50, blue: 0.20)
            case -500:  return Color(red: 0.15, green: 0.62, blue: 0.30)
            default:    return Color(red: 0.30, green: 0.75, blue: 0.45)
            }
        default:
            return Color(.systemGray3)
        }
    }

    var textColor: Color {
        weightPlan == "maintain" ? .primary : .white
    }
}
