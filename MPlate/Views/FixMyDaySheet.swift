//
//  FixMyDaySheet.swift
//  MPlate
//

import SwiftUI

struct FixMyDaySheet: View {
    @ObservedObject var aiService: AIService
    @Environment(\.dismiss) private var dismiss
    let diningHall: String
    let totalCalories: Int
    let totalProtein: Int
    let totalFat: Int
    let totalCarbs: Int
    let calorieGoal: Int
    let proteinGoal: Int
    let fatGoal: Int
    let carbGoal: Int
    var onRegenerate: (() async -> Void)?

    // Track which items are selected for adding
    @State private var selectedItems: Set<String> = []
    // Track which meal blocks have been saved
    @State private var savedBlocks: Set<String> = []
    @State private var saveError: String?
    @State private var allItemsSelected = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if aiService.isFixMyDayLoading {
                        HStack {
                            Spacer()
                            VStack(spacing: 12) {
                                ProgressView()
                                Text("Building your plan…")
                                    .foregroundStyle(Color.gray)
                                    .font(.subheadline)
                            }
                            .padding(.top, 40)
                            Spacer()
                        }
                    } else if let err = aiService.fixMyDayError {
                        Text(err)
                            .foregroundStyle(Color.red)
                            .padding()
                    } else if let plan = aiService.fixMyDayPlan {
                        // Current status card
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Where you stand")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.secondary)
                            HStack(spacing: 16) {
                                MacroStatusPill(label: "Cal", current: totalCalories, goal: calorieGoal)
                                MacroStatusPill(label: "Pro", current: totalProtein, goal: proteinGoal)
                                MacroStatusPill(label: "Fat", current: totalFat, goal: fatGoal)
                                MacroStatusPill(label: "Carbs", current: totalCarbs, goal: carbGoal)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)

                        // AI analysis
                        Text(plan.analysis)
                            .font(.subheadline)
                            .foregroundStyle(Color.secondary)
                            .padding(.horizontal)

                        if let err = saveError {
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(Color.red)
                                .padding(.horizontal)
                        }

                        // Meal blocks
                        ForEach(plan.mealBlocks, id: \.mealName) { block in
                            let blockSaved = savedBlocks.contains(block.mealName)

                            VStack(alignment: .leading, spacing: 0) {
                                // Block header
                                HStack {
                                    Image(systemName: mealIcon(for: block.mealName))
                                        .foregroundStyle(Color.mmaize)
                                    Text(block.mealName)
                                        .font(.headline)
                                    Spacer()
                                    Text("\(block.blockCalories) cal")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.mBlue)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 10)

                                // Block macro summary
                                HStack(spacing: 12) {
                                    MiniMacroLabel(label: "P", value: block.blockProtein, unit: "g")
                                    MiniMacroLabel(label: "F", value: block.blockFat, unit: "g")
                                    MiniMacroLabel(label: "C", value: block.blockCarbs, unit: "g")
                                }
                                .padding(.horizontal)
                                .padding(.bottom, 8)

                                Divider().padding(.horizontal)

                                // Items with toggle
                                ForEach(block.items, id: \.name) { item in
                                    let itemKey = "\(block.mealName)|\(item.name)"
                                    let isSelected = selectedItems.contains(itemKey)

                                    HStack(alignment: .top, spacing: 10) {
                                        // Selection toggle
                                        Button {
                                            if isSelected {
                                                selectedItems.remove(itemKey)
                                            } else {
                                                selectedItems.insert(itemKey)
                                            }
                                        } label: {
                                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                                .foregroundStyle(isSelected ? Color.mBlue : Color(.systemGray3))
                                                .font(.system(size: 20))
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(blockSaved)

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(item.name)
                                                .font(.system(size: 15, weight: .semibold))
                                                .strikethrough(blockSaved, color: .secondary)
                                            HStack(spacing: 8) {
                                                Text(item.portion)
                                                    .font(.caption2)
                                                    .foregroundStyle(Color.mBlue)
                                                Text("\(item.calories) cal")
                                                    .font(.caption2)
                                                    .foregroundStyle(Color.mBlue)
                                                Text("\(item.protein)g P")
                                                    .font(.caption2)
                                                    .foregroundStyle(Color.secondary)
                                                Text("\(item.fat)g F")
                                                    .font(.caption2)
                                                    .foregroundStyle(Color.secondary)
                                                Text("\(item.carbs)g C")
                                                    .font(.caption2)
                                                    .foregroundStyle(Color.secondary)
                                            }
                                            if !item.reason.isEmpty {
                                                Text(item.reason)
                                                    .font(.caption2)
                                                    .foregroundStyle(Color.gray)
                                            }
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                                    .opacity(blockSaved ? 0.5 : 1.0)
                                    Divider().padding(.leading, 52)
                                }

                                // Add to Tracker button per block
                                if blockSaved {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color.green)
                                        Text("Added to \(block.mealName)")
                                            .font(.caption)
                                            .foregroundStyle(Color.green)
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                } else {
                                    Button {
                                        addBlockToTracker(block: block)
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.caption)
                                            Text("Add to \(block.mealName)")
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                        }
                                        .foregroundStyle(Color.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Color.mBlue)
                                        .cornerRadius(10)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                            .padding(.horizontal)
                        }

                        // Add all blocks button
                        if !plan.mealBlocks.isEmpty && savedBlocks.count < plan.mealBlocks.count {
                            Button {
                                for block in plan.mealBlocks where !savedBlocks.contains(block.mealName) {
                                    addBlockToTracker(block: block)
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "tray.and.arrow.down.fill")
                                        .font(.caption)
                                    Text("Add All to Tracker")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                                .foregroundStyle(Color.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    LinearGradient(
                                        colors: [Color.mBlue, Color.mmaize],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                            .buttonStyle(.plain)
                        }

                        // All saved — done message
                        if !plan.mealBlocks.isEmpty && savedBlocks.count == plan.mealBlocks.count {
                            VStack(spacing: 8) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.title)
                                    .foregroundStyle(Color.green)
                                Text("All meals added to your tracker!")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.green)
                                Button("Done") {
                                    dismiss()
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Color.mBlue)
                                .padding(.top, 4)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }

                        // Projected totals
                        let projCal = totalCalories + plan.mealBlocks.reduce(0) { $0 + $1.blockCalories }
                        let projPro = totalProtein + plan.mealBlocks.reduce(0) { $0 + $1.blockProtein }
                        let projFat = totalFat + plan.mealBlocks.reduce(0) { $0 + $1.blockFat }
                        let projCarbs = totalCarbs + plan.mealBlocks.reduce(0) { $0 + $1.blockCarbs }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Projected totals")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.secondary)
                            HStack(spacing: 16) {
                                MacroStatusPill(label: "Cal", current: projCal, goal: calorieGoal)
                                MacroStatusPill(label: "Pro", current: projPro, goal: proteinGoal)
                                MacroStatusPill(label: "Fat", current: projFat, goal: fatGoal)
                                MacroStatusPill(label: "Carbs", current: projCarbs, goal: carbGoal)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)

                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "wand.and.stars")
                                .font(.largeTitle)
                                .foregroundStyle(Color.mmaize)
                            Text("Tap below to generate a plan that balances your remaining meals.")
                                .font(.subheadline)
                                .foregroundStyle(Color.gray)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 40)
                        .padding(.horizontal, 32)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .navigationTitle("Fix My Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Color.mBlue)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        if aiService.fixMyDayPlan != nil && !aiService.isFixMyDayLoading {
                            Button {
                                savedBlocks.removeAll()
                                selectedItems.removeAll()
                                saveError = nil
                                Task { await onRegenerate?() }
                            } label: {
                                Image(systemName: "arrow.clockwise")
                                    .font(.caption)
                                    .foregroundStyle(Color.mBlue)
                            }
                        }
                        Text(diningHall.replacingOccurrences(of: " Dining Hall", with: ""))
                            .font(.caption)
                            .foregroundStyle(Color.gray)
                    }
                }
            }
            .onAppear {
                // Select all items by default
                if let plan = aiService.fixMyDayPlan {
                    for block in plan.mealBlocks {
                        for item in block.items {
                            selectedItems.insert("\(block.mealName)|\(item.name)")
                        }
                    }
                }
            }
            .onChange(of: aiService.fixMyDayPlan?.analysis) { _, _ in
                // Re-select all when plan regenerates
                selectedItems.removeAll()
                if let plan = aiService.fixMyDayPlan {
                    for block in plan.mealBlocks {
                        for item in block.items {
                            selectedItems.insert("\(block.mealName)|\(item.name)")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Save a meal block to the tracker DB

    private func addBlockToTracker(block: FixMyDayPlan.MealBlock) {
        let date = DatabaseManager.getCurrentDate()
        let mealName = normalizeMealName(block.mealName)

        do {
            let mealID = try DatabaseManager.getOrCreateMealID(date: date, mealName: mealName)

            for item in block.items {
                let itemKey = "\(block.mealName)|\(item.name)"
                guard selectedItems.contains(itemKey) else { continue }

                try DatabaseManager.addFoodItem(
                    meal_id: mealID,
                    name: item.name,
                    kcal: "\(item.calories)kcal",
                    pro: "\(item.protein)gm",
                    fat: "\(item.fat)gm",
                    cho: "\(item.carbs)gm",
                    serving: item.portion,
                    qty: "1"
                )
            }

            savedBlocks.insert(block.mealName)
            saveError = nil
        } catch {
            saveError = "Failed to save \(mealName): \(error.localizedDescription)"
        }
    }

    private func normalizeMealName(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("breakfast") { return "Breakfast" }
        if lower.contains("lunch") || lower.contains("brunch") { return "Lunch" }
        if lower.contains("dinner") { return "Dinner" }
        return "Other"
    }

    private func mealIcon(for name: String) -> String {
        switch name.lowercased() {
        case let n where n.contains("breakfast"): return "sunrise.fill"
        case let n where n.contains("lunch"), let n where n.contains("brunch"): return "sun.max.fill"
        case let n where n.contains("dinner"): return "moon.fill"
        default: return "fork.knife"
        }
    }
}

// MARK: - Helper views

private struct MacroStatusPill: View {
    let label: String
    let current: Int
    let goal: Int

    private var fraction: Double {
        guard goal > 0 else { return 0 }
        return Double(current) / Double(goal)
    }

    private var statusColor: Color {
        if fraction > 1.1 { return .red }
        if fraction > 0.9 { return .green }
        return .mBlue
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.secondary)
            Text("\(current)")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(statusColor)
            Text("/\(goal)")
                .font(.caption2)
                .foregroundStyle(Color.secondary)
        }
    }
}

private struct MiniMacroLabel: View {
    let label: String
    let value: Int
    let unit: String

    var body: some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(Color.mmaize)
            Text("\(value)\(unit)")
                .font(.caption2)
                .foregroundStyle(Color.secondary)
        }
    }
}
