//
//  SelectorView.swift
//  MPlate
//

import SwiftUI
import GRDB

struct Selector: View {
    @AppStorage("selectedDiningHall") var selectedDiningHall: String = "Mosher Jordan Dining Hall"
    @State var mealAddingTo: String
    @State private var menu: Menu?
    @State private var selectedItems: Set<String> = []
    @State var selectedMeal = "Breakfast"
    @State var jsonBug = false
    @State var hallChanging = false
    @EnvironmentObject var toggleManager: ToggleManager
    @State private var quantities: [String: String] = [:]
    @State private var specialMenu: Menu?
    @State private var addButtonPressed: Bool = false
    @State private var noMenuItems: Bool = true
    @State private var preLoaded = false
    @StateObject private var aiService = AIService()
    @State private var showAISheet = false
    @State private var remainingCalories: Int = 0
    @State private var remainingProtein: Int = 0
    @State private var weightGoal: String = "maintain"
    @State private var customItems: [CustomItemRow] = []
    @State private var selectedCustomItemIds: Set<Int64> = []
    @State private var mealExpanded: Bool = true
    @State private var extrasExpanded: Bool = true
    @State private var customExpanded: Bool = true
    @State private var otherMenu: Menu?
    @State private var otherExpanded: Bool = true

    // @AppStorage handles persistence automatically
    private func updateSelectedDiningHallCache() {}

    var availableMenuItems: [AIMenuItem] {
        guard let meals = menu?.meal else { return [] }
        var items: [AIMenuItem] = []
        for meal in meals {
            if let courses = meal.course?.courseitem {
                for course in courses {
                    for item in course.menuitem.item {
                        if let itemName = item.name, let nutrition = item.itemsize?.nutrition {
                            let cal  = Int(nutrition.kcal?.replacingOccurrences(of: "kcal", with: "") ?? "0") ?? 0
                            let pro  = Int(nutrition.pro?.replacingOccurrences(of: "gm", with: "").trimmingCharacters(in: .whitespaces) ?? "0") ?? 0
                            let fat  = Int(nutrition.fat?.replacingOccurrences(of: "gm", with: "").trimmingCharacters(in: .whitespaces) ?? "0") ?? 0
                            let carb = Int(nutrition.cho?.replacingOccurrences(of: "gm", with: "").trimmingCharacters(in: .whitespaces) ?? "0") ?? 0
                            items.append(AIMenuItem(name: itemName, kcal: cal, protein: pro, fat: fat, carbs: carb))
                        }
                    }
                }
            }
        }
        return items
    }

    private func fetchData() {
        preLoaded = false
        MenuService.fetchMenu(diningHall: selectedDiningHall) { fetchedMenu, isDemoData in
            self.menu = fetchedMenu
            self.hallChanging = false
            self.preLoaded = isDemoData
            if fetchedMenu != nil {
                self.noMenuItems = false
            }
        }
        otherMenu = MenuService.loadOtherMenu(diningHall: selectedDiningHall)
    }

    private func loadBudget() {
        let budget = DatabaseManager.fetchRemainingBudget()
        remainingCalories = budget.calories
        remainingProtein = budget.protein
        weightGoal = budget.weightGoal
    }

    func saveSelectedItemsToDatabase() {
        do {
            let date = DatabaseManager.getCurrentDate()
            let validMealID = try DatabaseManager.getOrCreateMealID(date: date, mealName: mealAddingTo)

            let allMenuSources: [Menu?] = [menu, specialMenu, otherMenu]
            var addedItems = Set<String>()
            for source in allMenuSources {
                guard let meals = source?.meal else { continue }
                for selectedItem in selectedItems {
                    for meal in meals {
                        if let courses = meal.course?.courseitem {
                            for course in courses {
                                if let item = course.menuitem.item.first(where: { $0.name == selectedItem }) {
                                    if addedItems.contains(selectedItem) { continue }
                                    addedItems.insert(selectedItem)
                                    if let nutrition = item.itemsize?.nutrition {
                                        try DatabaseManager.addFoodItem(
                                            meal_id: validMealID,
                                            name: selectedItem,
                                            kcal: nutrition.kcal ?? "0kcal",
                                            pro: nutrition.pro ?? "0gm",
                                            fat: nutrition.fat ?? "0gm",
                                            cho: nutrition.cho ?? "0gm",
                                            serving: item.itemsize?.serving_size ?? "N/A",
                                            qty: quantities[selectedItem] ?? "1"
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }

            for itemId in selectedCustomItemIds {
                if let item = customItems.first(where: { $0.id == itemId }) {
                    try DatabaseManager.addFoodItem(
                        meal_id: validMealID,
                        name: item.name,
                        kcal: item.kcal,
                        pro: item.pro,
                        fat: item.fat,
                        cho: item.cho,
                        serving: item.serving,
                        qty: quantities["custom_\(item.id)"] ?? "1"
                    )
                }
            }

            print("Items successfully added to the database.")
        } catch {
            print("Failed to add items: \(error)")
        }
    }

    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    Picker("Select Dining Hall", selection: $selectedDiningHall) {
                        ForEach(hallNames, id: \.self) { hall in
                            Text(hall).tag(hall)
                        }
                        .onChange(of: selectedDiningHall) { oldValue, newValue in
                            hallChanging = true
                            noMenuItems = true
                            updateSelectedDiningHallCache()
                            preLoaded = false
                            fetchData()
                        }
                    }
                    .accentColor(Color.primary)
                    .padding(.leading, 2)

                    Spacer()

                    Button {
                        loadBudget()
                        showAISheet = true
                        Task {
                            await aiService.getDiningRecommendations(
                                menuItems: availableMenuItems,
                                remainingCalories: remainingCalories,
                                remainingProtein: remainingProtein,
                                weightGoal: weightGoal
                            )
                        }
                    } label: {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Color.mmaize)
                            .font(.title3)
                    }
                    .padding(.trailing, 8)
                    .disabled(availableMenuItems.isEmpty)

                    NavigationLink(destination: Custom(menu: $menu, quantities: $quantities, selectedItems: $selectedItems, mealAddingTo: mealAddingTo)) {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Custom")
                        }
                    }
                    .padding(.trailing, 15)
                }

                if preLoaded {
                    Text("Old menus loaded. Connect to U-M Wifi to use Updated Menus.")
                        .foregroundStyle(Color.gray)
                        .padding(.horizontal, 8)
                }

                ScrollView {
                    if let meals = menu?.meal {
                        if hallChanging == false {
                            ForEach(meals.filter { $0.name?.lowercased() == mealAddingTo.lowercased() }, id: \.name) { meal in
                                if meal.course != nil {
                                    Button(action: { withAnimation { mealExpanded.toggle() } }) {
                                        HStack {
                                            Text(meal.name?.lowercased().capitalized ?? "Unnamed Meal")
                                                .font(.largeTitle)
                                                .bold()
                                                .foregroundStyle(Color.white)
                                            Spacer()
                                            Image(systemName: mealExpanded ? "chevron.up" : "chevron.down")
                                                .foregroundStyle(Color.white)
                                                .font(.title2)
                                                .padding(.trailing, 8)
                                        }
                                        .frame(width: 340, height: 60)
                                        .padding(.horizontal)
                                        .background(Color(.mBlue))
                                        .cornerRadius(13)
                                        .padding(.bottom, 8)
                                    }
                                    .buttonStyle(.plain)
                                }
                                if mealExpanded, let courses = meal.course?.courseitem {
                                    ForEach(courses, id: \.name) { course in
                                        VStack {
                                            HStack {
                                                Text(course.name ?? "Unnamed Course")
                                                    .foregroundStyle(Color.mmaize)
                                                    .font(.title3)
                                                    .fontWeight(.bold)
                                                    .padding(.leading, 15)
                                                    .padding(.bottom, 4)
                                                    .onAppear { noMenuItems = false }
                                                Spacer()
                                            }
                                            ForEach(course.menuitem.item, id: \.name) { menuItem in
                                                VStack {
                                                    HStack {
                                                        Text(menuItem.name ?? "Unnamed MenuItem")
                                                            .font(.system(size: 14))
                                                            .padding(.leading, 15)
                                                            .fontWeight(.semibold)
                                                        NavigationLink(destination: NutritionViewer(name: menuItem.name ?? "Unnamed MenuItem", kcal: menuItem.itemsize?.nutrition?.kcal ?? "0kcal", pro: menuItem.itemsize?.nutrition?.pro ?? "0gm", fat: menuItem.itemsize?.nutrition?.fat ?? "0gm", cho: menuItem.itemsize?.nutrition?.cho ?? "0gm", serving: menuItem.itemsize?.serving_size ?? "N/A")) {
                                                            Image(systemName: "info.circle")
                                                                .resizable()
                                                                .frame(width: 17, height: 17)
                                                        }
                                                        Spacer()
                                                        let key = menuItem.name ?? ""
                                                        if selectedItems.contains(key) {
                                                            TextField("qty", text: Binding(
                                                                get: { quantities[key] ?? "1" },
                                                                set: { quantities[key] = $0 }
                                                            ))
                                                            .keyboardType(.decimalPad)
                                                            .frame(width: 44)
                                                            .multilineTextAlignment(.center)
                                                            .textFieldStyle(.roundedBorder)
                                                        }
                                                        Toggle(isOn: Binding(
                                                            get: { selectedItems.contains(key) },
                                                            set: { isSelected in
                                                                if isSelected {
                                                                    selectedItems.insert(key)
                                                                    quantities[key] = "1"
                                                                } else {
                                                                    selectedItems.remove(key)
                                                                }
                                                            }
                                                        )) {
                                                            Image(systemName: selectedItems.contains(key) ? "checkmark.square.fill" : "square")
                                                                .foregroundStyle(Color.mBlue)
                                                                .animation(nil, value: selectedItems)
                                                                .font(.title)
                                                        }
                                                        .sensoryFeedback(.increase, trigger: selectedItems)
                                                        .labelsHidden()
                                                        .toggleStyle(.button)
                                                        .padding(.trailing, 15)
                                                        .buttonStyle(.plain)
                                                    }
                                                    Divider()
                                                }
                                            }
                                        }.padding(.bottom, 8)
                                    }
                                }
                            }

                            // Other menu items (non-daily: condiments, beverages, etc.)
                            if mealAddingTo.lowercased() == "other", let otherMeals = otherMenu?.meal {
                                ForEach(otherMeals.filter { $0.name?.lowercased() == "other" }, id: \.name) { meal in
                                    if meal.course != nil {
                                        Button(action: { withAnimation { otherExpanded.toggle() } }) {
                                            HStack {
                                                Text("Other")
                                                    .font(.largeTitle)
                                                    .bold()
                                                    .foregroundStyle(Color.white)
                                                Spacer()
                                                Image(systemName: otherExpanded ? "chevron.up" : "chevron.down")
                                                    .foregroundStyle(Color.white)
                                                    .font(.title2)
                                                    .padding(.trailing, 8)
                                            }
                                            .frame(width: 340, height: 60)
                                            .padding(.horizontal)
                                            .background(Color(.mBlue))
                                            .cornerRadius(13)
                                            .padding(.bottom, 8)
                                        }
                                        .buttonStyle(.plain)
                                        .onAppear { noMenuItems = false }
                                    }
                                    if otherExpanded, let courses = meal.course?.courseitem {
                                        ForEach(courses, id: \.name) { course in
                                            VStack {
                                                HStack {
                                                    Text(course.name ?? "Unnamed Course")
                                                        .foregroundStyle(Color.mmaize)
                                                        .font(.title3)
                                                        .fontWeight(.bold)
                                                        .padding(.leading, 15)
                                                        .padding(.bottom, 4)
                                                    Spacer()
                                                }
                                                ForEach(course.menuitem.item, id: \.name) { menuItem in
                                                    VStack {
                                                        HStack {
                                                            Text(menuItem.name ?? "Unnamed MenuItem")
                                                                .font(.system(size: 14))
                                                                .padding(.leading, 15)
                                                                .fontWeight(.semibold)
                                                            NavigationLink(destination: NutritionViewer(name: menuItem.name ?? "Unnamed MenuItem", kcal: menuItem.itemsize?.nutrition?.kcal ?? "0kcal", pro: menuItem.itemsize?.nutrition?.pro ?? "0gm", fat: menuItem.itemsize?.nutrition?.fat ?? "0gm", cho: menuItem.itemsize?.nutrition?.cho ?? "0gm", serving: menuItem.itemsize?.serving_size ?? "N/A")) {
                                                                Image(systemName: "info.circle")
                                                                    .resizable()
                                                                    .frame(width: 17, height: 17)
                                                            }
                                                            Spacer()
                                                            let key = menuItem.name ?? ""
                                                            if selectedItems.contains(key) {
                                                                TextField("qty", text: Binding(
                                                                    get: { quantities[key] ?? "1" },
                                                                    set: { quantities[key] = $0 }
                                                                ))
                                                                .keyboardType(.decimalPad)
                                                                .frame(width: 44)
                                                                .multilineTextAlignment(.center)
                                                                .textFieldStyle(.roundedBorder)
                                                            }
                                                            Toggle(isOn: Binding(
                                                                get: { selectedItems.contains(key) },
                                                                set: { isSelected in
                                                                    if isSelected {
                                                                        selectedItems.insert(key)
                                                                        quantities[key] = "1"
                                                                    } else {
                                                                        selectedItems.remove(key)
                                                                    }
                                                                }
                                                            )) {
                                                                Image(systemName: selectedItems.contains(key) ? "checkmark.square.fill" : "square")
                                                                    .foregroundStyle(Color.mBlue)
                                                                    .animation(nil, value: selectedItems)
                                                                    .font(.title)
                                                            }
                                                            .sensoryFeedback(.increase, trigger: selectedItems)
                                                            .labelsHidden()
                                                            .toggleStyle(.button)
                                                            .padding(.trailing, 15)
                                                            .buttonStyle(.plain)
                                                        }
                                                        Divider()
                                                    }
                                                }
                                            }.padding(.bottom, 8)
                                        }
                                    }
                                }
                            }

                            if !noMenuItems {
                                if let specialMeals = specialMenu?.meal {
                                    ForEach(specialMeals, id: \.name) { meal in
                                        if meal.course != nil {
                                            Button(action: { withAnimation { extrasExpanded.toggle() } }) {
                                                HStack {
                                                    Text(meal.name?.lowercased().capitalized ?? "Extras")
                                                        .font(.largeTitle)
                                                        .bold()
                                                        .foregroundStyle(Color.white)
                                                    Spacer()
                                                    Image(systemName: extrasExpanded ? "chevron.up" : "chevron.down")
                                                        .foregroundStyle(Color.white)
                                                        .font(.title2)
                                                        .padding(.trailing, 8)
                                                }
                                                .frame(width: 340, height: 60)
                                                .padding(.horizontal)
                                                .background(Color(.mBlue))
                                                .cornerRadius(13)
                                                .padding(.bottom, 8)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        if extrasExpanded, let courses = meal.course?.courseitem {
                                            ForEach(courses, id: \.name) { course in
                                                VStack {
                                                    if course.name?.lowercased() != "special" {
                                                        HStack {
                                                            Text(course.name ?? "Unnamed Course")
                                                                .foregroundStyle(Color.mmaize)
                                                                .font(.title3)
                                                                .fontWeight(.bold)
                                                                .padding(.leading, 15)
                                                                .padding(.bottom, 4)
                                                            Spacer()
                                                        }
                                                    }
                                                    ForEach(course.menuitem.item, id: \.name) { menuItem in
                                                        let key = menuItem.name ?? ""
                                                        VStack {
                                                            HStack {
                                                                Text(menuItem.name ?? "Unnamed Item")
                                                                    .font(.system(size: 14))
                                                                    .padding(.leading, 15)
                                                                    .fontWeight(.semibold)
                                                                NavigationLink(destination: NutritionViewer(
                                                                    name: menuItem.name ?? "",
                                                                    kcal: menuItem.itemsize?.nutrition?.kcal ?? "0kcal",
                                                                    pro: menuItem.itemsize?.nutrition?.pro ?? "0gm",
                                                                    fat: menuItem.itemsize?.nutrition?.fat ?? "0gm",
                                                                    cho: menuItem.itemsize?.nutrition?.cho ?? "0gm",
                                                                    serving: menuItem.itemsize?.serving_size ?? "N/A"
                                                                )) {
                                                                    Image(systemName: "info.circle")
                                                                        .resizable()
                                                                        .frame(width: 17, height: 17)
                                                                }
                                                                Spacer()
                                                                if selectedItems.contains(key) {
                                                                    TextField("qty", text: Binding(
                                                                        get: { quantities[key] ?? "1" },
                                                                        set: { quantities[key] = $0 }
                                                                    ))
                                                                    .keyboardType(.decimalPad)
                                                                    .frame(width: 44)
                                                                    .multilineTextAlignment(.center)
                                                                    .textFieldStyle(.roundedBorder)
                                                                }
                                                                Toggle(isOn: Binding(
                                                                    get: { selectedItems.contains(key) },
                                                                    set: { isSelected in
                                                                        if isSelected {
                                                                            selectedItems.insert(key)
                                                                            quantities[key] = "1"
                                                                        } else {
                                                                            selectedItems.remove(key)
                                                                        }
                                                                    }
                                                                )) {
                                                                    Image(systemName: selectedItems.contains(key) ? "checkmark.square.fill" : "square")
                                                                        .foregroundStyle(Color.mBlue)
                                                                        .animation(nil, value: selectedItems)
                                                                        .font(.title)
                                                                }
                                                                .sensoryFeedback(.increase, trigger: selectedItems)
                                                                .labelsHidden()
                                                                .toggleStyle(.button)
                                                                .padding(.trailing, 15)
                                                                .buttonStyle(.plain)
                                                            }
                                                            Divider()
                                                        }
                                                    }
                                                }.padding(.bottom, 8)
                                            }
                                        }
                                    }
                                }

                                // Custom foods section
                                if !customItems.isEmpty {
                                    Button(action: { withAnimation { customExpanded.toggle() } }) {
                                        HStack {
                                            Text("Custom")
                                                .font(.largeTitle)
                                                .bold()
                                                .foregroundStyle(Color.white)
                                            Spacer()
                                            Image(systemName: customExpanded ? "chevron.up" : "chevron.down")
                                                .foregroundStyle(Color.white)
                                                .font(.title2)
                                                .padding(.trailing, 8)
                                        }
                                        .frame(width: 340, height: 60)
                                        .padding(.horizontal)
                                        .background(Color(.mBlue))
                                        .cornerRadius(13)
                                        .padding(.bottom, 8)
                                    }
                                    .buttonStyle(.plain)
                                    if customExpanded {
                                        ForEach(customItems, id: \.id) { item in
                                            VStack {
                                                HStack {
                                                    Text(item.name)
                                                        .font(.system(size: 14))
                                                        .padding(.leading, 15)
                                                        .fontWeight(.semibold)
                                                    NavigationLink(destination: NutritionViewer(name: item.name, kcal: item.kcal, pro: item.pro, fat: item.fat, cho: item.cho, serving: item.serving)) {
                                                        Image(systemName: "info.circle")
                                                            .resizable()
                                                            .frame(width: 17, height: 17)
                                                    }
                                                    Spacer()
                                                    if selectedCustomItemIds.contains(item.id) {
                                                        TextField("qty", text: Binding(
                                                            get: { quantities["custom_\(item.id)"] ?? "1" },
                                                            set: { quantities["custom_\(item.id)"] = $0 }
                                                        ))
                                                        .keyboardType(.decimalPad)
                                                        .frame(width: 44)
                                                        .multilineTextAlignment(.center)
                                                        .textFieldStyle(.roundedBorder)
                                                    }
                                                    Toggle(isOn: Binding(
                                                        get: { selectedCustomItemIds.contains(item.id) },
                                                        set: { isSelected in
                                                            if isSelected {
                                                                selectedCustomItemIds.insert(item.id)
                                                                quantities["custom_\(item.id)"] = "1"
                                                            } else {
                                                                selectedCustomItemIds.remove(item.id)
                                                            }
                                                        }
                                                    )) {
                                                        Image(systemName: selectedCustomItemIds.contains(item.id) ? "checkmark.square.fill" : "square")
                                                            .foregroundStyle(Color.mBlue)
                                                            .animation(nil, value: selectedCustomItemIds)
                                                            .font(.title)
                                                    }
                                                    .sensoryFeedback(.increase, trigger: selectedCustomItemIds)
                                                    .labelsHidden()
                                                    .toggleStyle(.button)
                                                    .padding(.trailing, 15)
                                                    .buttonStyle(.plain)
                                                }
                                                Divider()
                                            }
                                        }
                                        .padding(.bottom, 8)
                                    }
                                }
                            } else {
                                Text("No menu items found!")
                                    .foregroundStyle(Color.gray)
                                    .padding()
                            }
                        } else if jsonBug == true {
                            Text("Error fetching menus.\nPlease connect to the U-M Wifi.")
                                .foregroundStyle(Color.gray)
                                .padding()
                        } else {
                            ProgressView()
                                .padding(.top, 15)
                            Text("Loading Menu...")
                                .foregroundStyle(Color.gray)
                        }
                    } else if jsonBug == true {
                        Text("Error fetching menus.\nPlease connect to the U-M Wifi.")
                            .foregroundStyle(Color.gray)
                            .padding()
                    } else {
                        ProgressView()
                            .padding(.top, 15)
                        Text("Loading Menu...")
                            .foregroundStyle(Color.gray)
                    }
                }

                Spacer()
            }
            .onAppear {
                fetchData()
                specialMenu = MenuService.loadSpecialMenu()
                loadBudget()
                customItems = DatabaseManager.loadCustomItems()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            NavigationLink(destination: Homepage()) {
                HStack {
                    Text("Add to \(mealAddingTo)")
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.mBlue)
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title)
                        .foregroundStyle(Color.mBlue)
                }
            }
            .simultaneousGesture(TapGesture().onEnded {
                addButtonPressed = true
                saveSelectedItemsToDatabase()
            })
        }
        .sheet(isPresented: $showAISheet) {
            AIRecommendationsSheet(aiService: aiService, diningHall: selectedDiningHall)
                .presentationDetents([.medium, .large])
        }
    }
}

#Preview {
    Selector(mealAddingTo: "Breakfast")
}
