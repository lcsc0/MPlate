//
//  CustomFoodView.swift
//  MPlate
//

import SwiftUI
import Combine
import GRDB

struct Custom: View {
    enum FocusedField {
        case int, dec
    }

    @State var selectedDiningHall: String = UserDefaults.standard.string(forKey: "selectedDiningHall") ?? "Mosher Jordan Dining Hall"
    @Binding var menu: Menu?
    @State var selectedMeal = "Breakfast"
    @State var jsonBug = false
    @State var hallChanging = false
    @EnvironmentObject var toggleManager: ToggleManager
    @Binding var quantities: [String: String]
    @State private var specialMenu: Menu?
    @State private var addButtonPressed: Bool = false
    @State private var noMenuItems: Bool = true
    @State private var preLoaded = false
    @State var pastItems: [FoodItem] = []

    @Binding var selectedItems: Set<String>
    @State var selectedCustomitems: Set<String> = []
    @State private var name: String = ""
    @State private var kcal: String = ""
    @State private var pro: String = ""
    @State private var fat: String = ""
    @State private var cho: String = ""
    @State private var qty: String = ""
    @State private var addToCustomList: Bool = true
    @State var mealAddingTo: String
    @FocusState private var focusedField: FocusedField?

    @StateObject private var foodSearch = FoodSearchService()
    @State private var searchQuery: String = ""
    @State private var showManualEntry: Bool = false
    @State private var showSearchResults: Bool = false

    private func updateSelectedDiningHallCache() {
        UserDefaults.standard.set(selectedDiningHall, forKey: "selectedDiningHall")
    }

    func saveSelectedItemsToDatabase() {
        guard let meals = menu?.meal else { return }
        print(selectedItems)

        do {
            let date = DatabaseManager.getCurrentDate()
            let validMealID = try DatabaseManager.getOrCreateMealID(date: date, mealName: mealAddingTo)

            var addedItems = Set<String>()

            for selectedItem in selectedItems {
                for meal in meals {
                    if let courses = meal.course?.courseitem {
                        for course in courses {
                            if let item = course.menuitem.item.first(where: { $0.name == selectedItem }) {
                                if addedItems.contains(selectedItem) { continue }
                                addedItems.insert(selectedItem)
                                if let nutrition = item.itemsize?.nutrition {
                                    let kcal = nutrition.kcal ?? "0kcal"
                                    let pro = nutrition.pro ?? "0gm"
                                    let fat = nutrition.fat ?? "0gm"
                                    let cho = nutrition.cho ?? "0gm"
                                    let serving = item.itemsize?.serving_size ?? "N/A"
                                    let qty = quantities[selectedItem] ?? "1"
                                    try DatabaseManager.addFoodItem(
                                        meal_id: validMealID,
                                        name: selectedItem,
                                        kcal: kcal,
                                        pro: pro,
                                        fat: fat,
                                        cho: cho,
                                        serving: serving,
                                        qty: qty
                                    )
                                }
                            }
                        }
                    }
                }
            }
            print("Items successfully added to the database.")
        } catch {
            print("Failed to add items: \(error)")
        }
    }

    func saveSelectedCustomItemsToDatabase() {
        guard menu?.meal != nil else { return }
        print(selectedCustomitems)

        do {
            let date = DatabaseManager.getCurrentDate()
            let validMealID = try DatabaseManager.getOrCreateMealID(date: date, mealName: mealAddingTo)

            var addedItems = Set<String>()

            for selectedItemID in selectedCustomitems {
                if let item = pastItems.first(where: { $0.id.description == selectedItemID }) {
                    if addedItems.contains(selectedItemID) { continue }
                    addedItems.insert(selectedItemID)
                    let selectedQty = quantities[item.id.description] ?? "1"
                    try DatabaseManager.addFoodItem(
                        meal_id: validMealID,
                        name: item.name,
                        kcal: item.kcal,
                        pro: item.pro,
                        fat: item.fat,
                        cho: item.cho,
                        serving: item.serving,
                        qty: selectedQty
                    )
                }
            }
            print("Custom items successfully added to the database.")
        } catch {
            print("Failed to add custom items: \(error)")
        }
    }

    func saveTextFieldsToDatabase(name: String, kcal: String, pro: String, fat: String, cho: String, qty: String) {
        let mealName = mealAddingTo

        if !(name.isEmpty && kcal.isEmpty && pro.isEmpty && pro.isEmpty && fat.isEmpty && cho.isEmpty && qty.isEmpty) {
            do {
                let date = DatabaseManager.getCurrentDate()
                let validMealID = try DatabaseManager.getOrCreateMealID(date: date, mealName: mealName)

                let sanitizedName = name.isEmpty ? "Custom Item" : name
                let sanitizedKcal = (kcal.isEmpty ? "0" : kcal) + "kcal"
                let sanitizedPro = (pro.isEmpty ? "0" : pro) + "gm"
                let sanitizedFat = (fat.isEmpty ? "0" : fat) + "gm"
                let sanitizedCho = (cho.isEmpty ? "0" : cho) + "gm"
                let sanitizedQty = qty.isEmpty ? "1" : qty

                try DatabaseManager.addFoodItem(
                    meal_id: validMealID,
                    name: sanitizedName,
                    kcal: sanitizedKcal,
                    pro: sanitizedPro,
                    fat: sanitizedFat,
                    cho: sanitizedCho,
                    serving: "Custom",
                    qty: sanitizedQty
                )
                print("Item successfully added to the database.")
            } catch {
                print("Failed to add item: \(error)")
            }
        }
        if (addToCustomList) && !(name.isEmpty && kcal.isEmpty && pro.isEmpty && pro.isEmpty && fat.isEmpty && cho.isEmpty && qty.isEmpty) {
            do {
                let sanitizedName = name.isEmpty ? "Custom Item" : name
                let sanitizedKcal = (kcal.isEmpty ? "0" : kcal) + "kcal"
                let sanitizedPro = (pro.isEmpty ? "0" : pro) + "gm"
                let sanitizedFat = (fat.isEmpty ? "0" : fat) + "gm"
                let sanitizedCho = (cho.isEmpty ? "0" : cho) + "gm"

                try DatabaseManager.addCustomItem(
                    name: sanitizedName,
                    kcal: sanitizedKcal,
                    pro: sanitizedPro,
                    fat: sanitizedFat,
                    cho: sanitizedCho,
                    serving: "Custom"
                )
                print("Item successfully added to the database.")
            } catch {
                print("Failed to add item: \(error)")
            }
        }
    }

    private func applySearchResult(_ result: FoodSearchResult) {
        name = result.name
        kcal  = "\(result.calories)"
        pro   = "\(result.protein)"
        fat   = "\(result.fat)"
        cho   = "\(result.carbs)"
        showManualEntry = true
        showSearchResults = false
        searchQuery = result.name
        foodSearch.clear()
    }

    private func removeItemFromCustomItems(itemID: Int64) {
        DatabaseManager.removeCustomItem(id: itemID)
        pastItems.removeAll { $0.id == itemID }
        selectedCustomitems.remove(itemID.description)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Food search
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Search Food")
                            .font(.headline)
                            .padding(.horizontal)
                            .padding(.top, 20)

                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(Color.gray)
                            TextField("e.g. Greek Yogurt, Chicken Breast…", text: $searchQuery)
                                .autocorrectionDisabled()
                                .onChange(of: searchQuery) { _, newValue in
                                    if newValue.isEmpty {
                                        foodSearch.clear()
                                        showSearchResults = false
                                    } else {
                                        showSearchResults = true
                                        foodSearch.search(query: newValue)
                                    }
                                }
                            if !searchQuery.isEmpty {
                                Button {
                                    searchQuery = ""
                                    foodSearch.clear()
                                    showSearchResults = false
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(Color.gray)
                                }
                            }
                        }
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .padding(.horizontal)

                        if showSearchResults {
                            if foodSearch.isLoading {
                                HStack {
                                    Spacer()
                                    ProgressView().padding(.vertical, 8)
                                    Spacer()
                                }
                            } else if let err = foodSearch.errorMessage {
                                Text(err)
                                    .foregroundStyle(Color.gray)
                                    .font(.caption)
                                    .padding(.horizontal)
                                    .padding(.bottom, 4)
                            } else if !foodSearch.results.isEmpty {
                                VStack(spacing: 0) {
                                    ForEach(foodSearch.results) { result in
                                        Button {
                                            applySearchResult(result)
                                        } label: {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(result.name)
                                                        .font(.system(size: 14, weight: .semibold))
                                                        .foregroundStyle(Color.primary)
                                                        .multilineTextAlignment(.leading)
                                                    Text("\(result.calories) cal · \(result.protein)g protein · \(result.fat)g fat · \(result.carbs)g carbs · \(result.servingSize)")
                                                        .font(.caption)
                                                        .foregroundStyle(Color.gray)
                                                }
                                                Spacer()
                                                Image(systemName: "plus.circle")
                                                    .foregroundStyle(Color.mBlue)
                                            }
                                            .padding(.horizontal)
                                            .padding(.vertical, 8)
                                        }
                                        Divider().padding(.leading)
                                    }
                                }
                                .background(Color(.systemBackground))
                                .cornerRadius(10)
                                .shadow(color: .black.opacity(0.07), radius: 4, y: 2)
                                .padding(.horizontal)
                            }
                        }

                        Button {
                            showManualEntry.toggle()
                            if showManualEntry { showSearchResults = false }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: showManualEntry ? "chevron.up" : "chevron.down")
                                    .font(.caption)
                                Text(showManualEntry ? "Hide manual entry" : "Enter manually")
                                    .font(.subheadline)
                            }
                            .foregroundStyle(Color.mBlue)
                            .padding(.horizontal)
                            .padding(.top, 6)
                        }
                    }
                    .padding(.bottom, 8)

                    // Manual entry
                    if showManualEntry {
                        VStack {
                            HStack {
                                TextField("Custom Item", text: $name)
                                    .disableAutocorrection(true)
                                    .frame(width: 150)
                                    .textFieldStyle(.roundedBorder)
                                    .focused($focusedField, equals: .int)
                                    .onReceive(Just(name)) { newValue in
                                        let filtered = newValue.filter { "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz 1234567890".contains($0) }
                                        if filtered != newValue { self.name = filtered }
                                    }
                                    .padding(.leading, 100)
                                Text("Name")
                                Spacer()
                            }.padding(.top, 12)
                            HStack {
                                TextField("0", text: $kcal)
                                    .frame(width: 100)
                                    .textFieldStyle(.roundedBorder)
                                    .focused($focusedField, equals: .int)
                                    .keyboardType(.numberPad)
                                    .onReceive(Just(kcal)) { newValue in
                                        let filtered = newValue.filter { "0123456789".contains($0) }
                                        if filtered != newValue { self.kcal = filtered }
                                    }
                                    .padding(.leading, 100)
                                Text("Calories (kcal)")
                                Spacer()
                            }
                            HStack {
                                TextField("0", text: $pro)
                                    .frame(width: 100)
                                    .textFieldStyle(.roundedBorder)
                                    .focused($focusedField, equals: .int)
                                    .keyboardType(.numberPad)
                                    .onReceive(Just(pro)) { newValue in
                                        let filtered = newValue.filter { "0123456789".contains($0) }
                                        if filtered != newValue { self.pro = filtered }
                                    }
                                    .padding(.leading, 100)
                                Text("Protein (g)")
                                Spacer()
                            }
                            HStack {
                                TextField("0", text: $fat)
                                    .frame(width: 100)
                                    .textFieldStyle(.roundedBorder)
                                    .focused($focusedField, equals: .int)
                                    .keyboardType(.numberPad)
                                    .onReceive(Just(fat)) { newValue in
                                        let filtered = newValue.filter { "0123456789".contains($0) }
                                        if filtered != newValue { self.fat = filtered }
                                    }
                                    .padding(.leading, 100)
                                Text("Fat (g)")
                                Spacer()
                            }
                            HStack {
                                TextField("0", text: $cho)
                                    .frame(width: 100)
                                    .textFieldStyle(.roundedBorder)
                                    .focused($focusedField, equals: .int)
                                    .keyboardType(.numberPad)
                                    .onReceive(Just(cho)) { newValue in
                                        let filtered = newValue.filter { "0123456789".contains($0) }
                                        if filtered != newValue { self.cho = filtered }
                                    }
                                    .padding(.leading, 100)
                                Text("Carbs (g)")
                                Spacer()
                            }
                            HStack {
                                TextField("1", text: $qty)
                                    .frame(width: 100)
                                    .textFieldStyle(.roundedBorder)
                                    .focused($focusedField, equals: .int)
                                    .keyboardType(.numberPad)
                                    .onReceive(Just(qty)) { newValue in
                                        let filtered = newValue.filter { "0123456789".contains($0) }
                                        if filtered != newValue { self.qty = filtered }
                                    }
                                    .padding(.leading, 100)
                                Text("Quantity (int)")
                                Spacer()
                            }
                        }
                    }

                    Toggle(isOn: $addToCustomList) {
                        HStack {
                            Text("Save to Custom Items List")
                                .font(.system(size: 16))
                            Image(systemName: addToCustomList ? "checkmark.square.fill" : "square")
                                .foregroundStyle(Color.blue)
                        }
                    }
                    .padding(.top, 8)
                    .fontWeight(.semibold)
                    .labelsHidden()
                    .toggleStyle(.button)
                    .buttonStyle(.plain)

                    ScrollView {
                        VStack {
                            if pastItems.isEmpty {
                                Text("Saved custom items will go here.")
                                    .font(.title3)
                                    .italic()
                                    .foregroundStyle(Color.gray)
                                    .padding()
                            }
                            ForEach(pastItems, id: \.id) { item in
                                VStack {
                                    HStack {
                                        Button(action: { removeItemFromCustomItems(itemID: item.id) }) {
                                            Image(systemName: "trash")
                                                .foregroundStyle(Color.mBlue)
                                        }
                                        .padding(.trailing, 4)
                                        Text(item.name)
                                            .font(.system(size: 14))
                                            .padding(.leading, 15)
                                            .fontWeight(.semibold)
                                        NavigationLink(destination: NutritionViewer(
                                            name: item.name,
                                            kcal: item.kcal,
                                            pro: item.pro,
                                            fat: item.fat,
                                            cho: item.cho,
                                            serving: item.serving
                                        )) {
                                            Image(systemName: "info.circle")
                                                .resizable()
                                                .frame(width: 17, height: 17)
                                        }
                                        Spacer()
                                        if selectedCustomitems.contains(item.id.description) {
                                            Picker("", selection: Binding(
                                                get: { quantities[item.id.description] ?? "1" },
                                                set: { quantities[item.id.description] = $0 }
                                            )) {
                                                ForEach(["0.5", "1", "2", "3", "4"], id: \.self) { q in
                                                    Text(q).tag(q)
                                                }
                                            }
                                            .accentColor(Color.primary)
                                        }
                                        Toggle(isOn: Binding(
                                            get: { selectedCustomitems.contains(item.id.description) },
                                            set: { isSelected in
                                                if isSelected {
                                                    selectedCustomitems.insert(item.id.description)
                                                } else {
                                                    selectedCustomitems.remove(item.id.description)
                                                }
                                            }
                                        )) {
                                            Image(systemName: selectedCustomitems.contains(item.id.description) ? "checkmark.square.fill" : "square")
                                                .foregroundStyle(Color.mBlue)
                                                .font(.title)
                                        }
                                        .sensoryFeedback(.increase, trigger: selectedCustomitems)
                                        .labelsHidden()
                                        .toggleStyle(.button)
                                        .padding(.trailing, 15)
                                        .buttonStyle(.plain)
                                    }
                                    Divider()
                                }
                            }
                        }
                    }
                    .frame(height: 200)
                    .padding()
                    .padding(.top, 20)

                    NavigationLink(destination: Homepage()) {
                        HStack {
                            Text("Add to \(mealAddingTo)")
                                .foregroundStyle(Color.white)
                                .frame(width: 150.0, height: 50.0)
                                .background(Color.mBlue)
                                .cornerRadius(13)
                                .padding(.top, 15)
                        }
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        saveTextFieldsToDatabase(name: name, kcal: kcal, pro: pro, fat: fat, cho: cho, qty: qty)
                        saveSelectedItemsToDatabase()
                        saveSelectedCustomItemsToDatabase()
                        print(selectedCustomitems)
                    })
                }
                .frame(width: 400)
                .onAppear {
                    pastItems = DatabaseManager.fetchPastItems()
                }
            }
        }
        .navigationTitle("Add Custom Item(s)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .keyboard) {
                Spacer()
            }
            ToolbarItem(placement: .keyboard) {
                Button {
                    focusedField = nil
                } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                }
            }
        }
    }
}
