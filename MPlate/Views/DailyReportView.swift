//
//  DailyReportView.swift
//  MaizePlate
//
//  Full nutrition report for the day, showing all tracked nutrients
//  with percentage of daily value based on the user's calorie goal.
//

import SwiftUI

struct DailyReportView: View {
    let totalCalories: Int
    let calorieGoal: Int
    let totalProtein: Int
    let totalFat: Int
    let totalCarbs: Int
    let totalFiber: Int
    let totalSodium: Int
    let totalSugar: Int
    let totalSatFat: Int
    let totalCholesterol: Int
    let totalCalcium: Int
    let totalIron: Int
    let totalVitC: Int
    let totalVitD: Int
    let totalPotassium: Int

    @Environment(\.dismiss) private var dismiss

    // FDA reference daily values (based on 2000 cal diet)
    private let fdaRef: [String: Double] = [
        "Calories":    2000,
        "Protein":     50,
        "Fat":         78,
        "Carbs":       275,
        "Fiber":       28,
        "Sodium":      2300,
        "Sugar":       50,
        "Sat Fat":     20,
        "Cholesterol": 300,
        "Calcium":     1300,
        "Iron":        18,
        "Vitamin C":   90,
        "Vitamin D":   20,
        "Potassium":   4700
    ]

    // Scale FDA reference to user's calorie goal
    private func dv(for nutrient: String, value: Int) -> Int {
        guard let ref = fdaRef[nutrient], ref > 0 else { return 0 }
        let scale = calorieGoal > 0 ? Double(calorieGoal) / 2000.0 : 1.0
        let adjustedRef = ref * scale
        return Int((Double(value) / adjustedRef) * 100)
    }

    private var caloriePct: Int {
        guard calorieGoal > 0 else { return 0 }
        return Int(Double(totalCalories) / Double(calorieGoal) * 100)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {

                    // Header
                    VStack(spacing: 4) {
                        Text("Today's Report")
                            .font(.title2).fontWeight(.bold)
                        Text("% Daily Value based on \(calorieGoal) cal goal")
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 16)

                    // Calorie summary ring
                    ZStack {
                        Circle()
                            .stroke(Color(.systemGray5), lineWidth: 14)
                            .frame(width: 130, height: 130)
                        Circle()
                            .trim(from: 0, to: min(1.0, Double(totalCalories) / max(1, Double(calorieGoal))))
                            .stroke(
                                totalCalories > calorieGoal ? Color.orange : Color.mBlue,
                                style: StrokeStyle(lineWidth: 14, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 130, height: 130)
                            .animation(.easeOut, value: totalCalories)
                        VStack(spacing: 2) {
                            Text("\(totalCalories)")
                                .font(.title2).fontWeight(.bold)
                            Text("/ \(calorieGoal) cal")
                                .font(.caption2)
                                .foregroundStyle(Color.secondary)
                            Text("\(caloriePct)% DV")
                                .font(.caption2).fontWeight(.semibold)
                                .foregroundStyle(Color.mBlue)
                        }
                    }
                    .padding(.bottom, 24)

                    // Macros section
                    sectionHeader("Macronutrients")

                    reportRow(label: "Protein",      value: totalProtein,   unit: "g",   pct: dv(for: "Protein",  value: totalProtein))
                    reportRow(label: "Fat",           value: totalFat,       unit: "g",   pct: dv(for: "Fat",      value: totalFat))
                    reportRow(label: "Carbohydrates", value: totalCarbs,     unit: "g",   pct: dv(for: "Carbs",    value: totalCarbs))
                    reportRow(label: "Dietary Fiber", value: totalFiber,     unit: "g",   pct: dv(for: "Fiber",    value: totalFiber))
                    reportRow(label: "Total Sugar",   value: totalSugar,     unit: "g",   pct: dv(for: "Sugar",    value: totalSugar))
                    reportRow(label: "Saturated Fat", value: totalSatFat,    unit: "g",   pct: dv(for: "Sat Fat",  value: totalSatFat))
                    reportRow(label: "Cholesterol",   value: totalCholesterol, unit: "mg", pct: dv(for: "Cholesterol", value: totalCholesterol))
                    reportRow(label: "Sodium",        value: totalSodium,    unit: "mg",  pct: dv(for: "Sodium",   value: totalSodium))

                    sectionHeader("Vitamins & Minerals")

                    reportRow(label: "Calcium",   value: totalCalcium,   unit: "mg",  pct: dv(for: "Calcium",   value: totalCalcium))
                    reportRow(label: "Iron",      value: totalIron,      unit: "mg",  pct: dv(for: "Iron",      value: totalIron))
                    reportRow(label: "Potassium", value: totalPotassium, unit: "mg",  pct: dv(for: "Potassium", value: totalPotassium))
                    reportRow(label: "Vitamin C", value: totalVitC,      unit: "mg",  pct: dv(for: "Vitamin C", value: totalVitC))
                    reportRow(label: "Vitamin D", value: totalVitD,      unit: "mcg", pct: dv(for: "Vitamin D", value: totalVitD))

                    Text("* % Daily Values are based on your \(calorieGoal) calorie goal, scaled from the FDA 2,000 calorie reference. Not all items may have complete nutrition data.")
                        .font(.caption2)
                        .foregroundStyle(Color.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(Color.mBlue)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 16)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private func reportRow(label: String, value: Int, unit: String, pct: Int) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text("\(value)\(unit)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("\(pct)% DV")
                    .font(.caption)
                    .foregroundStyle(pct >= 100 ? Color.green : Color.secondary)
                    .frame(width: 58, alignment: .trailing)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 3)
                    Rectangle()
                        .fill(pct >= 100 ? Color.green : Color.mBlue)
                        .frame(width: geo.size.width * min(1.0, Double(pct) / 100.0), height: 3)
                }
            }
            .frame(height: 3)
            .padding(.horizontal)
        }
        .background(Color(.systemBackground))

        Divider().padding(.leading)
    }
}
