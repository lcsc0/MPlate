//
//  SetupView.swift
//  MPlate
//

import SwiftUI
import GRDB

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

#Preview {
    Setup()
}
