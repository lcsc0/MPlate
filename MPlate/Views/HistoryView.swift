//
//  HistoryView.swift
//  MPlate
//

import SwiftUI
import Charts

struct History: SwiftUI.View {

    @State private var breakfastItems: [FoodItem] = []
    @State private var lunchItems: [FoodItem] = []
    @State private var dinnerItems: [FoodItem] = []
    @State private var otherItems: [FoodItem] = []
    @State private var totalCalories: Int = 0
    @State private var totalProtein: Int = 0
    @State private var totalFat: Int = 0
    @State private var totalCarbs: Int = 0
    @State private var CalorieGoal: Int64 = 2000
    @State private var selectedDate: Date = Date()
    @State private var calorieTrend: [DayCalories] = []
    @State private var trendPeriod: TrendPeriod = .oneMonth

    private func formattedCurrentDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: selectedDate)
    }

    private func refreshView() {
        CalorieGoal = DatabaseManager.getCurrentCalorieGoal()
        calorieTrend = DatabaseManager.loadCalorieTrend(days: trendPeriod.days)
        let date = formattedCurrentDate()
        DatabaseManager.getFoodItemsForMeal(date: date, mealname: "Breakfast") { items in
            breakfastItems = items
        }
        DatabaseManager.getFoodItemsForMeal(date: date, mealname: "Lunch") { items in
            lunchItems = items
        }
        DatabaseManager.getFoodItemsForMeal(date: date, mealname: "Dinner") { items in
            dinnerItems = items
        }
        DatabaseManager.getFoodItemsForMeal(date: date, mealname: "Other") { items in
            otherItems = items
        }
        totalCalories = GetTotalNutrient(bitems: breakfastItems, litems: lunchItems, ditems: dinnerItems, oitems: otherItems, nutrientKey: "kcal")
        totalProtein = GetTotalNutrient(bitems: breakfastItems, litems: lunchItems, ditems: dinnerItems, oitems: otherItems, nutrientKey: "pro")
        totalFat = GetTotalNutrient(bitems: breakfastItems, litems: lunchItems, ditems: dinnerItems, oitems: otherItems, nutrientKey: "fat")
        totalCarbs = GetTotalNutrient(bitems: breakfastItems, litems: lunchItems, ditems: dinnerItems, oitems: otherItems, nutrientKey: "cho")
    }

    var body: some SwiftUI.View {
        NavigationStack {
            VStack(spacing: 0) {
                // Fixed top bar — macros only
                VStack(spacing: 4) {
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
                        .padding(.bottom, 6)
                }
                .padding(.top, 8)

                // Everything below is scrollable
                ScrollView {
                    VStack(spacing: 0) {

                    // Calorie trend chart
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Calorie Trend")
                                .font(.headline)
                            Spacer()
                            Picker("Period", selection: $trendPeriod) {
                                ForEach(TrendPeriod.allCases, id: \.self) { p in
                                    Text(p.rawValue).tag(p)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 220)
                        }
                        .padding(.horizontal)
                        .onChange(of: trendPeriod) { _, _ in
                            calorieTrend = DatabaseManager.loadCalorieTrend(days: trendPeriod.days)
                        }
                        if !calorieTrend.isEmpty {
                            Chart {
                                ForEach(calorieTrend) { point in
                                    LineMark(
                                        x: .value("Date", point.dateValue),
                                        y: .value("Calories", point.calories)
                                    )
                                    .foregroundStyle(Color.mBlue)
                                    .interpolationMethod(.catmullRom)
                                    AreaMark(
                                        x: .value("Date", point.dateValue),
                                        y: .value("Calories", point.calories)
                                    )
                                    .foregroundStyle(Color.mBlue.opacity(0.15))
                                    .interpolationMethod(.catmullRom)
                                }
                                if CalorieGoal > 0 {
                                    RuleMark(y: .value("Goal", CalorieGoal))
                                        .foregroundStyle(Color.mmaize.opacity(0.8))
                                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                                        .annotation(position: .top, alignment: .trailing) {
                                            Text("Goal")
                                                .font(.caption2)
                                                .foregroundStyle(Color.mmaize)
                                        }
                                }
                            }
                            .frame(height: 160)
                            .padding(.horizontal)
                            .chartXAxis {
                                AxisMarks(values: .automatic) { _ in
                                    AxisGridLine()
                                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                                }
                            }
                        } else {
                            Text("No data logged in this period")
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
                                .frame(height: 160)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 8)

                    DatePicker("Select Date:", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(GraphicalDatePickerStyle())
                        .padding()

                    // Meal sections
                    VStack {
                        HStack {
                            Text("Breakfast")
                                .font(.title2)
                                .multilineTextAlignment(.leading)
                                .padding(.leading, 123.0)
                            Spacer()
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
                            }.padding(.leading, 15)
                                .padding(.trailing, 15)
                                .padding(.vertical, 8)
                            Divider()
                        }
                    }
                    VStack {
                        HStack {
                            Text("Lunch")
                                .font(.title2)
                                .multilineTextAlignment(.leading)
                                .padding(.leading, 123.0)
                            Spacer()
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
                            }.padding(.leading, 15)
                                .padding(.trailing, 15)
                                .padding(.vertical, 8)
                            Divider()
                        }
                    }
                    } // end inner VStack
                } // end ScrollView
            }
            .onAppear {
                refreshView()
            }
            .onChange(of: selectedDate) { oldValue, newValue in
                refreshView()
            }
        }
    }
}
