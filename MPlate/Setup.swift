//
//  Setup.swift
//  MPlate
//

import SwiftUI
import GRDB

// MARK: - Activity Level

private enum ActivityLevel: String, CaseIterable, Identifiable {
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
        case .light:       return "Light exercise 1–3 days/week"
        case .moderate:    return "Moderate exercise 3–5 days/week"
        case .active:      return "Hard exercise 6–7 days/week"
        case .extraActive: return "Very hard exercise or physical job"
        }
    }
}

// MARK: - Goal Row Model

private struct GoalRow: Identifiable {
    let id = UUID()
    let label: String
    let subtitle: String
    let offset: Int        // calories relative to TDEE
    let weightPlan: String // "gain", "maintain", or "lose"

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

// MARK: - Screen 1: TDEE Calculator

struct Setup: View {
    @State private var isMale: Bool = true
    @State private var ageInput: String = ""
    @State private var heightFeetInput: String = ""
    @State private var heightInchesInput: String = ""
    @State private var weightInput: String = ""
    @State private var activityLevel: ActivityLevel = .moderate
    @State private var bodyFatInput: String = ""
    @State private var navigateToResults: Bool = false
    @State private var calculatedTDEE: Int = 0

    var body: some View {
        Form {
                Section(header: Text("Biological Sex")) {
                    Picker("Sex", selection: $isMale) {
                        Text("Male").tag(true)
                        Text("Female").tag(false)
                    }
                    .pickerStyle(.segmented)
                }

                Section(header: Text("Age")) {
                    HStack {
                        TextField("e.g. 20", text: $ageInput)
                            .keyboardType(.numberPad)
                        Text("years")
                            .foregroundStyle(.secondary)
                    }
                }

                Section(header: Text("Height")) {
                    HStack {
                        TextField("e.g. 5", text: $heightFeetInput)
                            .keyboardType(.numberPad)
                        Text("ft")
                            .foregroundStyle(.secondary)
                        Divider()
                        TextField("e.g. 7", text: $heightInchesInput)
                            .keyboardType(.numberPad)
                        Text("in")
                            .foregroundStyle(.secondary)
                    }
                }

                Section(header: Text("Weight")) {
                    HStack {
                        TextField("e.g. 155", text: $weightInput)
                            .keyboardType(.numberPad)
                        Text("lbs")
                            .foregroundStyle(.secondary)
                    }
                }

                Section(header: Text("Activity Level")) {
                    Picker("Activity", selection: $activityLevel) {
                        ForEach(ActivityLevel.allCases) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                    .pickerStyle(.menu)
                    Text(activityLevel.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section(
                    header: Text("Body Fat % (Optional)"),
                    footer: Text("If provided, uses the more accurate Katch-McArdle formula.")
                ) {
                    TextField("e.g. 18", text: $bodyFatInput)
                        .keyboardType(.decimalPad)
                }

                Section {
                    Button(action: {
                        calculatedTDEE = computeTDEE()
                        navigateToResults = true
                    }) {
                        HStack {
                            Spacer()
                            Text("Calculate")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(.vertical, 8)
                            Spacer()
                        }
                        .background(Color.mBlue)
                        .cornerRadius(10)
                    }
                    .listRowInsets(EdgeInsets())
                }
            }
        .navigationTitle("TDEE Calculator")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(isPresented: $navigateToResults) {
            TDEEResults(tdee: calculatedTDEE)
        }
    }

    private func computeTDEE() -> Int {
        let weightKg = (Double(weightInput) ?? 155) * 0.453592
        let feet = Double(heightFeetInput) ?? 5
        let inches = Double(heightInchesInput) ?? 7
        let heightCm = (feet * 12.0 + inches) * 2.54
        let age = Double(ageInput) ?? 20
        let bmr: Double

        if let bf = Double(bodyFatInput.trimmingCharacters(in: .whitespaces)),
           bf > 0, bf < 100 {
            let lbm = weightKg * (1.0 - bf / 100.0)
            bmr = 370.0 + 21.6 * lbm
        } else {
            if isMale {
                bmr = 10.0 * weightKg + 6.25 * heightCm - 5.0 * age + 5.0
            } else {
                bmr = 10.0 * weightKg + 6.25 * heightCm - 5.0 * age - 161.0
            }
        }

        return Int((bmr * activityLevel.factor).rounded())
    }
}

// MARK: - Screen 2: Goal Picker

private struct TDEEResults: View {
    let tdee: Int
    @State private var navigateToHomepage: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                // TDEE banner
                VStack(spacing: 6) {
                    Text("Your TDEE")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(formatted(tdee))
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.mBlue)
                    Text("calories / day to maintain your weight")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 28)
                .padding(.horizontal)

                // Goal rows
                VStack(spacing: 10) {
                    ForEach(GoalRow.all) { row in
                        let calories = tdee + row.offset
                        let pct = tdee > 0
                            ? Int((Double(calories) / Double(tdee) * 100).rounded())
                            : 100

                        Button {
                            saveGoal(calories: calories, plan: row.weightPlan)
                            navigateToHomepage = true
                        } label: {
                            HStack(spacing: 0) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(row.label)
                                        .font(.headline)
                                        .foregroundStyle(row.textColor)
                                    Text(row.subtitle)
                                        .font(.subheadline)
                                        .foregroundStyle(row.textColor.opacity(0.80))
                                }
                                .padding(.leading, 16)
                                .padding(.vertical, 14)

                                Spacer()

                                VStack(alignment: .trailing, spacing: 2) {
                                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                                        Text(formatted(calories))
                                            .font(.title2.weight(.bold))
                                            .foregroundStyle(row.textColor)
                                        Text("\(pct)%")
                                            .font(.caption)
                                            .foregroundStyle(row.textColor.opacity(0.80))
                                    }
                                    Text("Calories/day")
                                        .font(.caption)
                                        .foregroundStyle(row.textColor.opacity(0.80))
                                }
                                .padding(.trailing, 16)
                                .padding(.vertical, 14)
                            }
                            .background(row.rowColor)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Choose Your Goal")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(isPresented: $navigateToHomepage) {
            Homepage()
                .navigationBarBackButtonHidden(true)
        }
    }

    private func saveGoal(calories: Int, plan: String) {
        do {
            try dbQueue.write { db in
                try db.execute(
                    sql: "UPDATE user SET caloriegoal = ?, weightplan = ?, firstSetupComplete = ? WHERE id = 1",
                    arguments: [calories, plan, true]
                )
            }
        } catch {
            print("TDEEResults saveGoal error: \(error)")
        }
    }

    private func formatted(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}

// MARK: - Preview

#Preview {
    Setup()
}
