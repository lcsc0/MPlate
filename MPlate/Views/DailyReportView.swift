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

    // User's custom nutrient goals from Settings
    @AppStorage("goalProtein")   private var goalProtein:   Int = 150
    @AppStorage("goalFat")       private var goalFat:       Int = 65
    @AppStorage("goalCarbs")     private var goalCarbs:     Int = 250
    @AppStorage("goalFiber")     private var goalFiber:     Int = 25
    @AppStorage("goalSodium")    private var goalSodium:    Int = 2300
    @AppStorage("goalSugar")     private var goalSugar:     Int = 50
    @AppStorage("goalCalcium")   private var goalCalcium:   Int = 1300
    @AppStorage("goalIron")      private var goalIron:      Int = 18
    @AppStorage("goalVitC")      private var goalVitC:      Int = 90
    @AppStorage("goalVitD")      private var goalVitD:      Int = 20
    @AppStorage("goalPotassium") private var goalPotassium: Int = 4700

    // FDA values for nutrients not in user goals
    private let fdaSatFat:     Double = 20
    private let fdaCholesterol: Double = 300

    private func pct(value: Int, goal: Int) -> Int {
        guard goal > 0 else { return 0 }
        return Int(Double(value) / Double(goal) * 100)
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
                        Text("% Daily Value based on your Settings goals")
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

                    reportRow(label: "Protein",      value: totalProtein,     unit: "g",   pct: pct(value: totalProtein,     goal: goalProtein))
                    reportRow(label: "Fat",           value: totalFat,         unit: "g",   pct: pct(value: totalFat,         goal: goalFat))
                    reportRow(label: "Carbohydrates", value: totalCarbs,       unit: "g",   pct: pct(value: totalCarbs,       goal: goalCarbs))
                    reportRow(label: "Dietary Fiber", value: totalFiber,       unit: "g",   pct: pct(value: totalFiber,       goal: goalFiber))
                    reportRow(label: "Total Sugar",   value: totalSugar,       unit: "g",   pct: pct(value: totalSugar,       goal: goalSugar))
                    reportRow(label: "Saturated Fat", value: totalSatFat,      unit: "g",   pct: Int(Double(totalSatFat)      / fdaSatFat      * 100))
                    reportRow(label: "Cholesterol",   value: totalCholesterol, unit: "mg",  pct: Int(Double(totalCholesterol) / fdaCholesterol  * 100))
                    reportRow(label: "Sodium",        value: totalSodium,      unit: "mg",  pct: pct(value: totalSodium,      goal: goalSodium))

                    sectionHeader("Vitamins & Minerals")

                    reportRow(label: "Calcium",   value: totalCalcium,   unit: "mg",  pct: pct(value: totalCalcium,   goal: goalCalcium))
                    reportRow(label: "Iron",      value: totalIron,      unit: "mg",  pct: pct(value: totalIron,      goal: goalIron))
                    reportRow(label: "Potassium", value: totalPotassium, unit: "mg",  pct: pct(value: totalPotassium, goal: goalPotassium))
                    reportRow(label: "Vitamin C", value: totalVitC,      unit: "mg",  pct: pct(value: totalVitC,      goal: goalVitC))
                    reportRow(label: "Vitamin D", value: totalVitD,      unit: "mcg", pct: pct(value: totalVitD,      goal: goalVitD))

                    Text("* % Daily Values use your custom goals from Settings. Sat Fat and Cholesterol use FDA references. Not all items may have complete nutrition data.")
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
