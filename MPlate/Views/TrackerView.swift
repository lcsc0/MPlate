//
//  TrackerView.swift
//  MPlate
//

import SwiftUI

struct Tracker: SwiftUI.View {

    @State private var breakfastItems: [FoodItem] = []
    @State private var lunchItems: [FoodItem] = []
    @State private var dinnerItems: [FoodItem] = []
    @State private var otherItems: [FoodItem] = []
    @State private var totalCalories: Int = 0
    @State private var totalProtein: Int = 0
    @State private var totalFat: Int = 0
    @State private var totalCarbs: Int = 0
    @State private var CalorieGoal: Int64 = 2000
    @AppStorage("goalProtein") private var goalProtein: Int = 150
    @AppStorage("goalFat") private var goalFat: Int = 65
    @AppStorage("goalCarbs") private var goalCarbs: Int = 250
    @AppStorage("goalFiber") private var goalFiber: Int = 25
    @AppStorage("goalSodium") private var goalSodium: Int = 2300
    @AppStorage("goalSugar") private var goalSugar: Int = 50
    @AppStorage("goalCalcium") private var goalCalcium: Int = 1300
    @AppStorage("goalIron") private var goalIron: Int = 18
    @AppStorage("goalVitC") private var goalVitC: Int = 90
    @AppStorage("goalVitD") private var goalVitD: Int = 20
    @AppStorage("goalPotassium") private var goalPotassium: Int = 4700
    @State private var showReport: Bool = false
    @State private var totalFiber: Int = 0
    @State private var totalSodium: Int = 0
    @State private var totalSugar: Int = 0
    @State private var totalSatFat: Int = 0
    @State private var totalCholesterol: Int = 0
    @State private var totalCalcium: Int = 0
    @State private var totalIron: Int = 0
    @State private var totalVitC: Int = 0
    @State private var totalVitD: Int = 0
    @State private var totalPotassium: Int = 0

    @AppStorage("selectedDiningHall") private var selectedDiningHall: String = "Mosher Jordan Dining Hall"
    @State private var showHallPickerSheet = false
    @State private var trackerMenuItems: [AIMenuItem] = []

    @StateObject private var aiService = AIService()

    private func buildMenuItems(from menu: Menu?) -> [AIMenuItem] {
        guard let meals = menu?.meal else { return [] }
        var items: [AIMenuItem] = []
        for meal in meals {
            if let courses = meal.course?.courseitem {
                for course in courses {
                    for item in course.menuitem.item {
                        if let name = item.name, let n = item.itemsize?.nutrition {
                            let cal  = Int(n.kcal?.replacingOccurrences(of: "kcal", with: "").trimmingCharacters(in: .whitespaces) ?? "0") ?? 0
                            let pro  = Int(n.pro?.replacingOccurrences(of: "gm", with: "").trimmingCharacters(in: .whitespaces) ?? "0") ?? 0
                            let fat  = Int(n.fat?.replacingOccurrences(of: "gm", with: "").trimmingCharacters(in: .whitespaces) ?? "0") ?? 0
                            let carb = Int(n.cho?.replacingOccurrences(of: "gm", with: "").trimmingCharacters(in: .whitespaces) ?? "0") ?? 0
                            let serving = item.itemsize?.serving_size ?? "1 serving"
                            items.append(AIMenuItem(name: name, kcal: cal, protein: pro, fat: fat, carbs: carb, serving: serving))
                        }
                    }
                }
            }
        }
        return items
    }

    private func recalculateTotals() {
        totalCalories = GetTotalNutrient(bitems: breakfastItems, litems: lunchItems, ditems: dinnerItems, oitems: otherItems, nutrientKey: "kcal")
        totalProtein = GetTotalNutrient(bitems: breakfastItems, litems: lunchItems, ditems: dinnerItems, oitems: otherItems, nutrientKey: "pro")
        totalFat = GetTotalNutrient(bitems: breakfastItems, litems: lunchItems, ditems: dinnerItems, oitems: otherItems, nutrientKey: "fat")
        totalCarbs = GetTotalNutrient(bitems: breakfastItems, litems: lunchItems, ditems: dinnerItems, oitems: otherItems, nutrientKey: "cho")
        totalFiber       = GetTotalNutrient(bitems: breakfastItems, litems: lunchItems, ditems: dinnerItems, oitems: otherItems, nutrientKey: "fiber")
        totalSodium      = GetTotalNutrient(bitems: breakfastItems, litems: lunchItems, ditems: dinnerItems, oitems: otherItems, nutrientKey: "sodium")
        totalSugar       = GetTotalNutrient(bitems: breakfastItems, litems: lunchItems, ditems: dinnerItems, oitems: otherItems, nutrientKey: "sugar")
        totalSatFat      = GetTotalNutrient(bitems: breakfastItems, litems: lunchItems, ditems: dinnerItems, oitems: otherItems, nutrientKey: "satFat")
        totalCholesterol = GetTotalNutrient(bitems: breakfastItems, litems: lunchItems, ditems: dinnerItems, oitems: otherItems, nutrientKey: "cholesterol")
        totalCalcium     = GetTotalNutrient(bitems: breakfastItems, litems: lunchItems, ditems: dinnerItems, oitems: otherItems, nutrientKey: "calcium")
        totalIron        = GetTotalNutrient(bitems: breakfastItems, litems: lunchItems, ditems: dinnerItems, oitems: otherItems, nutrientKey: "iron")
        totalVitC        = GetTotalNutrient(bitems: breakfastItems, litems: lunchItems, ditems: dinnerItems, oitems: otherItems, nutrientKey: "vitC")
        totalVitD        = GetTotalNutrient(bitems: breakfastItems, litems: lunchItems, ditems: dinnerItems, oitems: otherItems, nutrientKey: "vitD")
        totalPotassium   = GetTotalNutrient(bitems: breakfastItems, litems: lunchItems, ditems: dinnerItems, oitems: otherItems, nutrientKey: "potassium")
    }

    private func deleteItem(item: FoodItem) {
        DatabaseManager.deleteFoodItem(id: item.id)
        breakfastItems.removeAll { $0.id == item.id }
        lunchItems.removeAll { $0.id == item.id }
        dinnerItems.removeAll { $0.id == item.id }
        otherItems.removeAll { $0.id == item.id }
        recalculateTotals()
    }

    var body: some SwiftUI.View {
        NavigationStack {
            VStack {
                HStack {
                    Text("Tracker")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 25)
                    Spacer()
                    Text("Maize")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.mmaize)
                    Text("Plate")
                        .font(.largeTitle)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.mBlue)
                        .padding(.trailing, 25.0)
                }.padding(.bottom, 10)
                    .padding(.top, 10)

                HStack {
                    VStack {
                        Text("Calories").bold()
                        Text("\(totalCalories)")
                    }.font(.title3).padding(.horizontal, 6)
                    VStack {
                        Text("Protein").bold()
                        Text("\(totalProtein)")
                    }.font(.title3).padding(.horizontal, 6)
                    VStack {
                        Text("Fat").bold()
                        Text("\(totalFat)")
                    }.font(.title3).padding(.horizontal, 6)
                    VStack {
                        Text("Carbs").bold()
                        Text("\(totalCarbs)")
                    }.font(.title3).padding(.horizontal, 6)
                }

                ProgressView(value: (Double(totalCalories) / Double(CalorieGoal)))
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(width: 400)
                    .padding(6)

                // Dining hall banner
                HStack {
                    Image(systemName: "fork.knife")
                        .foregroundStyle(Color.mBlue)
                        .font(.caption)
                    Text("Eating at:")
                        .font(.caption)
                        .foregroundStyle(Color.gray)
                    Text(selectedDiningHall.replacingOccurrences(of: " Dining Hall", with: ""))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.mBlue)
                    Spacer()
                    Button("Change") {
                        showHallPickerSheet = true
                    }
                    .font(.caption)
                    .foregroundStyle(Color.mBlue)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 4)
                .sheet(isPresented: $showHallPickerSheet) {
                    NavigationStack {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(hallNames, id: \.self) { hall in
                                Button {
                                    selectedDiningHall = hall
                                    showHallPickerSheet = false
                                } label: {
                                    HStack {
                                        Text(hall)
                                            .foregroundStyle(Color.primary)
                                        Spacer()
                                        if hall == selectedDiningHall {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(Color.mBlue)
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 14)
                                }
                                Divider().padding(.leading)
                            }
                        }
                        .navigationTitle("Select Dining Hall")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") { showHallPickerSheet = false }
                            }
                        }
                    }
                    .presentationDetents([.medium, .large])
                }

                // AI Suggestions card
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Color.mmaize)
                        Text("AI Suggestions")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                        Button {
                            Task {
                                await aiService.getTrackerSuggestions(
                                    totalCalories: totalCalories,
                                    totalProtein: totalProtein,
                                    totalFat: totalFat,
                                    totalCarbs: totalCarbs,
                                    calorieGoal: Int(CalorieGoal),
                                    diningHall: selectedDiningHall,
                                    menuItems: trackerMenuItems
                                )
                            }
                        } label: {
                            if aiService.isLoading {
                                ProgressView()
                                    .scaleEffect(0.75)
                            } else {
                                Text(aiService.suggestion == nil ? "Get Tips" : "Refresh")
                                    .font(.caption)
                                    .foregroundStyle(Color.mBlue)
                            }
                        }
                        .disabled(aiService.isLoading)
                    }

                    if let err = aiService.errorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(Color.red)
                    } else if let s = aiService.suggestion {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(s.summary)
                                    .font(.caption)
                                    .foregroundStyle(Color.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                ForEach(s.tips, id: \.self) { tip in
                                    HStack(alignment: .top, spacing: 6) {
                                        Text("•").foregroundStyle(Color.mBlue)
                                        Text(tip).font(.caption)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                if !s.recommendedItems.isEmpty {
                                    Divider().padding(.vertical, 2)
                                    ForEach(s.recommendedItems, id: \.name) { item in
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.name)
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                                .fixedSize(horizontal: false, vertical: true)
                                            Text("\(item.portion) · \(item.calories) cal")
                                                .font(.caption2)
                                                .foregroundStyle(Color.mBlue)
                                            Text(item.reason)
                                                .font(.caption2)
                                                .foregroundStyle(Color.secondary)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        .padding(.vertical, 2)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal, 18)
                .padding(.bottom, 4)

                ScrollView {
                    VStack {
                        HStack {
                            Text("Breakfast")
                                .font(.title2)
                                .multilineTextAlignment(.leading)
                                .padding(.leading, 123.0)
                            Spacer()
                            NavigationLink(destination: Selector(mealAddingTo: "Breakfast")) {
                                Image(systemName: "plus.app.fill")
                                    .resizable()
                                    .frame(width: 35, height: 35)
                                    .foregroundStyle(Color.mmaize)
                                    .padding(16)
                            }
                        }.foregroundStyle(Color.white)
                            .frame(width: 360, height: 60)
                            .background(Color.mBlue)
                            .clipShape(RoundedRectangle(cornerSize: CGSize(width: 13, height: 10)))

                        ForEach(breakfastItems, id: \.id) { item in
                            HStack {
                                Text(item.name + " (\(item.kcal.dropLast(4)) Cal)")
                                NavigationLink(destination: NutritionViewer(name: item.name, kcal: item.kcal, pro: item.pro, fat: item.fat, cho: item.cho, serving: item.serving)) {
                                    Image(systemName: "info.circle")
                                        .resizable()
                                        .font(.title)
                                        .frame(width: 20, height: 20)
                                }
                                Spacer()
                                Text("x" + item.qty)
                                    .padding(.trailing, 8)
                                Button(action: { deleteItem(item: item) }) {
                                    Image(systemName: "trash")
                                        .resizable()
                                        .foregroundStyle(Color.mBlue)
                                        .frame(width: 20, height: 25)
                                }
                            }.padding(.leading, 15)
                                .padding(.trailing, 15)
                                .padding(.vertical, 8)
                            Divider()
                        }
                    }
                    VStack {
                        HStack {
                            Text(Calendar.current.isDateInWeekend(Date()) ? "Lunch / Brunch" : "Lunch")
                                .font(.title2)
                                .multilineTextAlignment(.leading)
                                .padding(.leading, Calendar.current.isDateInWeekend(Date()) ? 85.0 : 123.0)
                            Spacer()
                            NavigationLink(destination: Selector(mealAddingTo: "Lunch")) {
                                Image(systemName: "plus.app.fill")
                                    .resizable()
                                    .frame(width: 35, height: 35)
                                    .foregroundStyle(Color.mmaize)
                                    .padding(16)
                            }
                        }.foregroundStyle(Color.white)
                            .frame(width: 360, height: 60)
                            .background(Color.mBlue)
                            .clipShape(RoundedRectangle(cornerSize: CGSize(width: 13, height: 10)))

                        ForEach(lunchItems, id: \.id) { item in
                            HStack {
                                Text(item.name + " (\(item.kcal.dropLast(4)) Cal)")
                                NavigationLink(destination: NutritionViewer(name: item.name, kcal: item.kcal, pro: item.pro, fat: item.fat, cho: item.cho, serving: item.serving)) {
                                    Image(systemName: "info.circle")
                                        .resizable()
                                        .font(.title)
                                        .frame(width: 20, height: 20)
                                }
                                Spacer()
                                Text("x" + item.qty)
                                    .padding(.trailing, 8)
                                Button(action: { deleteItem(item: item) }) {
                                    Image(systemName: "trash")
                                        .resizable()
                                        .foregroundStyle(Color.mBlue)
                                        .frame(width: 20, height: 25)
                                }
                            }.padding(.leading, 15)
                                .padding(.trailing, 15)
                                .padding(.vertical, 8)
                            Divider()
                        }
                    }
                    VStack {
                        HStack {
                            Text("Dinner")
                                .font(.title2)
                                .multilineTextAlignment(.leading)
                                .padding(.leading, 123.0)
                            Spacer()
                            NavigationLink(destination: Selector(mealAddingTo: "Dinner")) {
                                Image(systemName: "plus.app.fill")
                                    .resizable()
                                    .frame(width: 35, height: 35)
                                    .foregroundStyle(Color.mmaize)
                                    .padding(16)
                            }
                        }.foregroundStyle(Color.white)
                            .frame(width: 360, height: 60)
                            .background(Color.mBlue)
                            .clipShape(RoundedRectangle(cornerSize: CGSize(width: 13, height: 10)))

                        ForEach(dinnerItems, id: \.id) { item in
                            HStack {
                                Text(item.name + " (\(item.kcal.dropLast(4)) Cal)")
                                NavigationLink(destination: NutritionViewer(name: item.name, kcal: item.kcal, pro: item.pro, fat: item.fat, cho: item.cho, serving: item.serving)) {
                                    Image(systemName: "info.circle")
                                        .resizable()
                                        .font(.title)
                                        .frame(width: 20, height: 20)
                                }
                                Spacer()
                                Text("x" + item.qty)
                                    .padding(.trailing, 8)
                                Button(action: { deleteItem(item: item) }) {
                                    Image(systemName: "trash")
                                        .resizable()
                                        .foregroundStyle(Color.mBlue)
                                        .frame(width: 20, height: 25)
                                }
                            }.padding(.leading, 15)
                                .padding(.trailing, 15)
                                .padding(.vertical, 8)
                            Divider()
                        }
                    }
                    VStack {
                        HStack {
                            Text("Other")
                                .font(.title2)
                                .multilineTextAlignment(.leading)
                                .padding(.leading, 123.0)
                            Spacer()
                            NavigationLink(destination: Selector(mealAddingTo: "Other")) {
                                Image(systemName: "plus.app.fill")
                                    .resizable()
                                    .frame(width: 35, height: 35)
                                    .foregroundStyle(Color.mmaize)
                                    .padding(16)
                            }
                        }.foregroundStyle(Color.white)
                            .frame(width: 360, height: 60)
                            .background(Color.mBlue)
                            .clipShape(RoundedRectangle(cornerSize: CGSize(width: 13, height: 10)))

                        ForEach(otherItems, id: \.id) { item in
                            HStack {
                                Text(item.name + " (\(item.kcal.dropLast(4)) Cal)")
                                NavigationLink(destination: NutritionViewer(name: item.name, kcal: item.kcal, pro: item.pro, fat: item.fat, cho: item.cho, serving: item.serving)) {
                                    Image(systemName: "info.circle")
                                        .resizable()
                                        .font(.title)
                                        .frame(width: 20, height: 20)
                                }
                                Spacer()
                                Text("x" + item.qty)
                                    .padding(.trailing, 8)
                                Button(action: { deleteItem(item: item) }) {
                                    Image(systemName: "trash")
                                        .resizable()
                                        .foregroundStyle(Color.mBlue)
                                        .frame(width: 20, height: 25)
                                }
                            }.padding(.leading, 15)
                                .padding(.trailing, 15)
                                .padding(.vertical, 8)
                            Divider()
                        }
                    }
                    // Generate Report button
                    Button {
                        showReport = true
                    } label: {
                        HStack {
                            Image(systemName: "doc.text.magnifyingglass")
                            Text("Generate Report")
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.mBlue)
                        .cornerRadius(13)
                        .padding(.horizontal, 18)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                    .buttonStyle(.plain)
                    .sheet(isPresented: $showReport) {
                        DailyReportView(
                            totalCalories: totalCalories,
                            calorieGoal: Int(CalorieGoal),
                            totalProtein: totalProtein,
                            totalFat: totalFat,
                            totalCarbs: totalCarbs,
                            totalFiber: totalFiber,
                            totalSodium: totalSodium,
                            totalSugar: totalSugar,
                            totalSatFat: totalSatFat,
                            totalCholesterol: totalCholesterol,
                            totalCalcium: totalCalcium,
                            totalIron: totalIron,
                            totalVitC: totalVitC,
                            totalVitD: totalVitD,
                            totalPotassium: totalPotassium
                        )
                    }
                }
            }
            .onAppear {
                let date = DatabaseManager.getCurrentDate()
                DatabaseManager.getFoodItemsForMeal(date: date, mealname: "Breakfast") { items in breakfastItems = items }
                DatabaseManager.getFoodItemsForMeal(date: date, mealname: "Lunch") { items in lunchItems = items }
                DatabaseManager.getFoodItemsForMeal(date: date, mealname: "Dinner") { items in dinnerItems = items }
                DatabaseManager.getFoodItemsForMeal(date: date, mealname: "Other") { items in otherItems = items }
                recalculateTotals()
                CalorieGoal = DatabaseManager.getCurrentCalorieGoal()
                // Load menu items for AI suggestions (uses cache after first load)
                MenuService.fetchMenu(diningHall: selectedDiningHall) { menu, _ in
                    var items = buildMenuItems(from: menu)
                    let otherMenu = MenuService.loadOtherMenu(diningHall: selectedDiningHall)
                    items += buildMenuItems(from: otherMenu)
                    trackerMenuItems = items
                }
            }
            Spacer()
        }
    }
}

private struct NutrientProgressRow: View {
    let label: String
    let value: Int
    let goal: Int
    let unit: String

    private var fraction: Double {
        guard goal > 0 else { return 0 }
        return min(1.0, Double(value) / Double(goal))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(Color.secondary)
                Spacer()
                Text("\(value)/\(goal)\(unit)")
                    .font(.caption2)
                    .foregroundStyle(Color.primary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.systemGray4))
                        .frame(height: 5)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(fraction >= 1.0 ? Color.green : Color.mBlue)
                        .frame(width: geo.size.width * fraction, height: 5)
                }
            }
            .frame(height: 5)
        }
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}
