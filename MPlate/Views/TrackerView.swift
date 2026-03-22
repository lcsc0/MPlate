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

    @AppStorage("selectedDiningHall") private var selectedDiningHall: String = "Mosher Jordan Dining Hall"
    @State private var showHallPickerSheet = false

    @StateObject private var aiService = AIService()

    private func recalculateTotals() {
        totalCalories = GetTotalNutrient(bitems: breakfastItems, litems: lunchItems, ditems: dinnerItems, oitems: otherItems, nutrientKey: "kcal")
        totalProtein = GetTotalNutrient(bitems: breakfastItems, litems: lunchItems, ditems: dinnerItems, oitems: otherItems, nutrientKey: "pro")
        totalFat = GetTotalNutrient(bitems: breakfastItems, litems: lunchItems, ditems: dinnerItems, oitems: otherItems, nutrientKey: "fat")
        totalCarbs = GetTotalNutrient(bitems: breakfastItems, litems: lunchItems, ditems: dinnerItems, oitems: otherItems, nutrientKey: "cho")
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
                    VStack {
                        VStack {
                            Text(String(formatNumberWithCommas(Int(CalorieGoal - Int64(totalCalories))) ?? ""))
                                .bold()
                            Text("Left")
                        }
                        .padding(5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.primary.opacity(0.3), lineWidth: 0.5)
                        )
                    }.padding(.horizontal, 6)
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
                                await aiService.getDailySummary(
                                    totalCalories: totalCalories,
                                    totalProtein: totalProtein,
                                    totalFat: totalFat,
                                    totalCarbs: totalCarbs,
                                    calorieGoal: Int(CalorieGoal)
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
                        Text(s.summary)
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                        ForEach(s.tips, id: \.self) { tip in
                            HStack(alignment: .top, spacing: 6) {
                                Text("•")
                                    .foregroundStyle(Color.mBlue)
                                Text(tip)
                                    .font(.caption)
                            }
                        }
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
            }
            Spacer()
        }
    }
}
