//
//  Selector.swift
//  Mkcals
//
//  Created by Grant Patterson on 10/18/24.
//

import SwiftUI

import GRDB

class ToggleManager: ObservableObject {
    @Published var demoMode: Bool = false
}


class APIHandling {
    //get url and format it
    static func getURL (diningHall: String) -> String {
        return "https://api.studentlife.umich.edu/menu/xml2print.php?controller=print&view=json&location=\(diningHall.replacingOccurrences(of: " ", with: "%20"))"
    }

}




struct Selector: View {
    @AppStorage("selectedDiningHall") var selectedDiningHall: String = "Mosher Jordan Dining Hall"
    @State var mealAddingTo: String
    @State private var menu: Menu? // Store the fetched menu data
    @State private var selectedItems: Set<String> = [] // Set to store selected menu items
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
    @State private var selectedCustomItemIds: Set<Int> = []

    struct CustomItemRow {
        let id: Int
        let name: String
        let kcal: String
        let pro: String
        let fat: String
        let cho: String
        let serving: String
    }



 
    let hallNames = [
        "Mosher Jordan Dining Hall",
        "Markley Dining Hall",
        "Bursley Dining Hall",
        "South Quad Dining Hall",
        "East Quad Dining Hall",
        "Twigs at Oxford",
        "North Quad Dining Hall",
        "Martha Cook Dining Hall",
        "Lawyers Club Dining Hall"
        
    ]
    
    // @AppStorage handles persistence automatically; kept for call-site compatibility
    private func updateSelectedDiningHallCache() {}

    // Build menu items list for AI from the loaded menu
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

    // Fetch remaining calories + protein from today's logged meals
    func loadCustomItems() {
        do {
            customItems = try dbQueue.read { db in
                let rows = try Row.fetchAll(db, sql: "SELECT id, name, kcal, pro, fat, cho, serving FROM customitems3 ORDER BY created_at DESC")
                return rows.map { row in
                    CustomItemRow(
                        id: row["id"] as! Int,
                        name: row["name"] as? String ?? "",
                        kcal: row["kcal"] as? String ?? "0kcal",
                        pro: row["pro"] as? String ?? "0gm",
                        fat: row["fat"] as? String ?? "0gm",
                        cho: row["cho"] as? String ?? "0gm",
                        serving: row["serving"] as? String ?? "N/A"
                    )
                }
            }
        } catch {
            print("Error loading custom items: \(error)")
        }
    }

    func fetchRemainingBudget() {
        do {
            let today = getCurrentDate()
            let calorieGoal = try dbQueue.read { db -> Int in
                let row = try Row.fetchOne(db, sql: "SELECT caloriegoal FROM user WHERE id = 1")
                return (row?["caloriegoal"] as? Int) ?? 2000
            }
            let totalKcal = try dbQueue.read { db -> Int in
                let query = """
                SELECT SUM(CAST(REPLACE(fi.kcal,'kcal','') AS REAL) * CAST(fi.qty AS REAL))
                FROM fooditems fi JOIN meals m ON fi.meal_id = m.id
                WHERE m.date = ?
                """
                return Int(try Double.fetchOne(db, sql: query, arguments: [today]) ?? 0)
            }
            let totalPro = try dbQueue.read { db -> Int in
                let query = """
                SELECT SUM(CAST(REPLACE(fi.pro,'gm','') AS REAL) * CAST(fi.qty AS REAL))
                FROM fooditems fi JOIN meals m ON fi.meal_id = m.id
                WHERE m.date = ?
                """
                return Int(try Double.fetchOne(db, sql: query, arguments: [today]) ?? 0)
            }
            let wGoal = try dbQueue.read { db -> String in
                let row = try Row.fetchOne(db, sql: "SELECT weightplan FROM user WHERE id = 1")
                return (row?["weightplan"] as? String) ?? "maintain"
            }
            DispatchQueue.main.async {
                remainingCalories = max(0, calorieGoal - totalKcal)
                // rough protein target: 0.8g per lb bodyweight placeholder; use remaining as 50g floor
                remainingProtein = max(0, 150 - totalPro)
                weightGoal = wGoal
            }
        } catch {
            print("fetchRemainingBudget error: \(error)")
        }
    }
    
    
    //demo mode
    func loadDemoData() {
        preLoaded = true
        noMenuItems = false
        print(selectedDiningHall.replacingOccurrences(of: " ", with: "_"))
        print(selectedDiningHall)
                                
                                                
        guard let path = Bundle.main.path(forResource: selectedDiningHall.replacingOccurrences(of: " ", with: "_"), ofType: "json") else {
            print("Demo JSON file not found.")
            return
        }
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            //print(path)
            let decoder = JSONDecoder()
            let itemFeed = try decoder.decode(apiCalled.self, from: data)

            
            //print raw json
            //if let jsonString = String(data: data, encoding: .utf8) {
                //print("JSON Response: \(jsonString)")
            //}
            //let customMeal1 = Meal()
            

            self.menu = itemFeed.menu
            
            print("Demo data loaded successfully.")
            hallChanging = false
        } catch {
            print("Error loading demo data: \(error)")
        }
    }
    func loadSpecialData() {
        guard let path = Bundle.main.path(forResource: "special_menu", ofType: "json") else {
            print("Special JSON file not found.")
            return
        }
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            //print(path)
            let decoder = JSONDecoder()
            let itemFeed = try decoder.decode(apiCalled.self, from: data)

            
            //print raw json
            //if let jsonString = String(data: data, encoding: .utf8) {
                //print("JSON Response: \(jsonString)")
            //}
            //let customMeal1 = Meal()
            

            self.specialMenu = itemFeed.menu
            
            print("Demo data loaded successfully.")
            hallChanging = false
        } catch {
            print("Error loading special data: \(error)")
        }
    }
    
    //api call
    func fetchData() {
            preLoaded = false
        
        //if toggleManager.demoMode {
            //loadDemoData()

          //  return
        //} else {
            
            let urlString = APIHandling.getURL(diningHall: selectedDiningHall)
            
            let url = URL(string: urlString)
            
            guard url != nil else {
                return
            }
            
            let session = URLSession.shared
            
            let dataTask = session.dataTask(with: url!) { (data,response,error) in
                
                //check for errors
                if error == nil && data != nil {
                    
                    
                    //parse json
                    let decoder = JSONDecoder()
                    
                    do{
                        
                        //print raw json
                        //if let jsonString = String(data: data!, encoding: .utf8) {
                        //print("JSON Response: \(jsonString)")
                        //}
                        
                        let itemFeed = try decoder.decode(apiCalled.self, from: data!)
                        //print(itemFeed)
                        DispatchQueue.main.async {
                            
                           
                            self.menu = itemFeed.menu //store decoded menu
                            
                            
                            
                            /* Print each course name and its menuitem names
                             if let meals = itemFeed.menu?.meal {
                             for meal in meals {
                             if let courses = meal.course?.courseitem {
                             for course in courses {
                             // Print the course name before the menuitems
                             if let courseName = course.name {
                             print("Course Name: \(courseName)")
                             }
                             
                             // Print each menuitem name under the course
                             for menuItem in course.menuitem.item {
                             if let itemName = menuItem.name {
                             print("  MenuItem Name: \(itemName)")
                             }
                             }
                             }
                             }
                             }
                             }*/
                            
                            
                        }
                        hallChanging = false
                        preLoaded = false
                        
                    } catch {
                        print("error: \(error)")
                        loadDemoData()
                        //jsonBug = true
                    }
                    
                } else {
                    loadDemoData()
                    //jsonBug = true
                }
                
            }
            //make the API Call
            dataTask.resume()
        //}
    }
    
    func getCurrentDate() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd" // Set the format to include only year, month, and day
        let currentDate = Date()
        return dateFormatter.string(from: currentDate)
    }
    
    func saveSelectedItemsToDatabase() {
        do {
            try DatabaseManager.addMeal(date: getCurrentDate(), mealName: mealAddingTo)

            let mealID = try dbQueue.read { db in
                try Int.fetchOne(db, sql: "SELECT id FROM meals WHERE date = ? AND mealname = ?", arguments: [getCurrentDate(), mealAddingTo])
            }

            guard let validMealID = mealID else { return }

            // Save selected menu items
            if let meals = menu?.meal {
                var addedItems = Set<String>()
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

            // Save selected custom items
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

    
    
    
    //Structs for JSON decoding
    struct apiCalled: Codable {
        var menu: Menu?
    }
    struct Menu: Codable {
        var meal: [Meal]?
    }
    struct Meal: Codable {
        var name: String?
        var course: CourseWrapper?
        
        struct CourseWrapper: Codable {
            var courseitem: [Course] //makes an array called courseitem to store all courses for the meal (whether it be single or mutliple)
            
            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let singleCourseItem = try? container.decode(Course.self) {
                    // If a single MenuItem is decoded, add it to the array
                    courseitem = [singleCourseItem]
                } else if let multipleItems = try? container.decode([Course].self) {
                    // If an array of MenuItem is decoded, assign it
                    courseitem = multipleItems
                } else {
                    throw DecodingError.typeMismatch(
                        CourseWrapper.self,
                        DecodingError.Context(
                            codingPath: decoder.codingPath,
                            debugDescription: "Expected single MenuItem or array of MenuItem."
                        )
                    )
                }
            }
            //array vs single item decoding for menuitem
            struct Course: Codable {
                var name: String?
                var menuitem: ItemWrapper
                
                struct ItemWrapper: Codable {
                    var item: [MenuItem]
                    
                    init(from decoder: Decoder) throws {
                        let container = try decoder.singleValueContainer()
                        if let singleItem = try? container.decode(MenuItem.self) {
                            // If a single MenuItem is decoded, add it to the array
                            item = [singleItem]
                        } else if let multipleItems = try? container.decode([MenuItem].self) {
                            // If an array of MenuItem is decoded, assign it
                            item = multipleItems
                        } else {
                            throw DecodingError.typeMismatch(
                                ItemWrapper.self,
                                DecodingError.Context(
                                    codingPath: decoder.codingPath,
                                    debugDescription: "Expected single MenuItem or array of MenuItem."
                                )
                            )
                        }
                    }
                    
                    func encode(to encoder: Encoder) throws {
                        var container = encoder.singleValueContainer()
                        if item.count == 1 {
                            try container.encode(item[0]) // Encode as a single item if there's only one
                        } else {
                            try container.encode(item) // Encode as an array if there are multiple items
                        }
                    }
                }
                
                struct MenuItem: Codable {
                    var name: String?
                    var itemsize: ItemSize? //added

                    
                    
                }
            }
            //end of array vs single item decoding
        }
    }
    
    
    

    
    
    // Struct for Nutrition (only 4 macros)
    struct Nutrition: Codable {
        var pro: String?  // Protein
        var fat: String?  // Fat
        var cho: String?  // Carbohydrates
        var kcal: String? // Calories
        
        // Initialize with default values
        init(from nutritionDict: [String: String]? = nil) {
            self.pro = nutritionDict?["pro"] ?? "0gm"
            self.fat = nutritionDict?["fat"] ?? "0gm"
            self.cho = nutritionDict?["cho"] ?? "0gm"
            self.kcal = nutritionDict?["kcal"] ?? "0kcal"
        }
    }

    // Struct for ItemSize, including Nutrition
    struct ItemSize: Codable {
        var serving_size: String?   // Optional, in case it's missing
        var portion_size: String?  // Optional, in case it's missing
        var nutrition: Nutrition?  // Optional, in case it's missing or malformed
        
        enum CodingKeys: String, CodingKey {
            case serving_size
            case portion_size
            case nutrition
        }
        
        // Custom initializer to handle the case where `nutrition` might be an empty array
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.serving_size = try? container.decode(String.self, forKey: .serving_size)
            self.portion_size = try? container.decode(String.self, forKey: .portion_size)
            
            // Attempt to decode `nutrition` as a dictionary
            if let nutritionDict = try? container.decode([String: String].self, forKey: .nutrition) {
                self.nutrition = Nutrition(from: nutritionDict)
            } else if let nutritionArray = try? container.decode([String].self, forKey: .nutrition), nutritionArray.isEmpty {
                // If `nutrition` is an empty array, initialize it with default values
                self.nutrition = Nutrition()
            } else {
                // Default to empty nutrition if unable to decode
                self.nutrition = Nutrition()
            }
        }
    }

    
    
    

    

    var body: some View {
        NavigationStack{
            VStack{
                HStack{

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
                    } .accentColor(Color.primary)
                    .padding(.leading,2)

                    Spacer()

                    // AI recommendation button
                    Button {
                        fetchRemainingBudget()
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
                        HStack{
                            Image(systemName: "plus.circle")
                            Text("Custom")
                        }
                    }
                    .padding(.trailing, 15)
                    /*if !preLoaded {
                        HStack{
                            Image(systemName: "dot.radiowaves.left.and.right")
                            
                                .foregroundStyle(Color.green)
                                .font(.system(size: 10))
                            Text("Up-To-Date")
                                .font(.system(size: 10))
                        }.padding(.trailing, 20)
                        
                        
                    }*/
                    
                }
                if preLoaded {
                    Text("Old menus loaded. Connect to U-M Wifi to use Updated Menus.")
                        .foregroundStyle(Color.gray)
                        .padding(.horizontal, 8)




                }
                ScrollView{
                    if let meals = menu?.meal{
                        if hallChanging == false{
                            ForEach(meals.filter { $0.name?.lowercased() == mealAddingTo.lowercased() }, id: \.name) { meal in
                                
                                if meal.course != nil {
                                    
                                    Text(meal.name?.lowercased().capitalized ?? "Unnamed Meal")
                                        
                                        .font(.largeTitle)
                                        .bold()
                                        .foregroundStyle(Color.white)
                                        .frame(width: 340, height: 60)
                                        .padding(.horizontal) // Add padding around the text
                                        .background(Color(.mBlue)) // Light gray background
                                        .cornerRadius(13) // Apply rounded corners
                                        
                                        .padding(.bottom, 8)
                                        
                                        
                                    
                                    
                                    
                                    
                                    
                                }
                                if let courses = meal.course?.courseitem {
                                    ForEach(courses, id: \.name) { course in
                                        VStack{
                                            HStack{
                                                Text(course.name ?? "Unnamed Course")
                                                    .foregroundStyle(Color.mmaize)
                                                    .font(.title3)
                                                    .fontWeight(.bold)
                                                    .padding(.leading, 15)
                                                //.underline(true)
                                                
                                                    .padding(.bottom, 4)
                                                    .onAppear {
                                                        noMenuItems = false
                                                    }
                                                    
                                                
                                                Spacer()
                                            }
                                            // Directly use `course.menuitem.item` without optional unwrapping
                                            
                                            ForEach(course.menuitem.item, id: \.name) { menuItem in
                                                
                                                VStack{
                                                    HStack{
                                                        Text(menuItem.name ?? "Unnamed MenuItem")
                                                            .font(. system(size: 14))
                                                            //.font(.title)
                                                            .padding(.leading, 15)
                                                            .fontWeight(.semibold)
                                                            
                                                        
                                                        
                                                        
                                                        NavigationLink(destination: NutritionViewer(name: menuItem.name ?? "Unnamed MenuItem", kcal: menuItem.itemsize?.nutrition?.kcal ?? "0kcal", pro: menuItem.itemsize?.nutrition?.pro ?? "0gm", fat: menuItem.itemsize?.nutrition?.fat ?? "0gm", cho: menuItem.itemsize?.nutrition?.cho ?? "0gm", serving: menuItem.itemsize?.serving_size ?? "N/A")){
                                                            Image(systemName: "info.circle")
                                                                .resizable()
                                                                .frame(width: 17, height: 17)
                                                                
                                                            
                                                        }
                                                        Spacer()
                                                        if selectedItems.contains(menuItem.name ?? "") {
                                                            Picker("", selection: Binding(
                                                                get: { quantities[menuItem.name ?? ""] ?? "1" },
                                                                set: { quantities[menuItem.name ?? ""] = $0 }
                                                            )) {
                                                                ForEach(["0.5", "1", "2", "3", "4"], id: \.self) { q in
                                                                    Text(q).tag(q)
                                                                }
                                                                
                                                            }
                                                            
                                                            .accentColor(Color.primary)
                                                        }


                                                        
                                                        Toggle(isOn: Binding(
                                                            get: { selectedItems.contains(menuItem.name ?? "") },
                                                            set: { isSelected in
                                                                if isSelected {
                                                                    selectedItems.insert(menuItem.name ?? "")
                                                                } else {
                                                                    selectedItems.remove(menuItem.name ?? "")
                                                                }
                                                            }
                                                        )) {
                                                            
                                                            Image(systemName: selectedItems.contains(menuItem.name ?? "") ? "checkmark.square.fill" : "square") // Empty square when unselected, filled when selected
                                                                .foregroundStyle(Color.mBlue)
                                                                                             
                                                                .animation(nil, value:selectedItems)
                                                            //.frame(height:25)
                                                                .font(.title)
                                                                
                                                        }
                                                        .sensoryFeedback(.increase, trigger: selectedItems)
                                                        .labelsHidden()
                                                        .toggleStyle(.button)
                                                        .padding(.trailing, 15)
                                                        .buttonStyle(.plain)
                                                        // Show Picker only when the Toggle is checked

                                                        
                                                        
                                                        
                                                    }
                                                    Divider()
                                                }
                                            }
                                        }.padding(.bottom, 8)
                                    }
                                    
                                }
                            }
                            
                            if !noMenuItems{
                                SpecialViewer(mealAddingTo: mealAddingTo, selectedItems: $selectedItems, addToMealButtonPressed: $addButtonPressed)

                                // Custom foods section
                                if !customItems.isEmpty {
                                    Text("Custom")
                                        .font(.largeTitle)
                                        .bold()
                                        .foregroundStyle(Color.white)
                                        .frame(width: 340, height: 60)
                                        .padding(.horizontal)
                                        .background(Color(.mBlue))
                                        .cornerRadius(13)
                                        .padding(.bottom, 8)

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
                                                    Picker("", selection: Binding(
                                                        get: { quantities["custom_\(item.id)"] ?? "1" },
                                                        set: { quantities["custom_\(item.id)"] = $0 }
                                                    )) {
                                                        ForEach(["0.5", "1", "2", "3", "4"], id: \.self) { q in
                                                            Text(q).tag(q)
                                                        }
                                                    }
                                                    .accentColor(Color.primary)
                                                }
                                                Toggle(isOn: Binding(
                                                    get: { selectedCustomItemIds.contains(item.id) },
                                                    set: { isSelected in
                                                        if isSelected { selectedCustomItemIds.insert(item.id) }
                                                        else { selectedCustomItemIds.remove(item.id) }
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
                            } else {
                                Text("No menu items found!")
                                    .foregroundStyle(Color.gray)
                                    .padding()
                            }
                        } else if jsonBug == true{
                            Text("Error fetching menus.\nPlease connect to the U-M Wifi.")
                                .foregroundStyle(Color.gray)
                                .padding()
                        }
                                
                        else {
                            ProgressView()
                                .padding(.top, 15)
                            Text("Loading Menu...")
                                .foregroundStyle(Color.gray)
                        }
                    } else if jsonBug == true{
                        Text("Error fetching menus.\nPlease connect to the U-M Wifi.")
                            .foregroundStyle(Color.gray)
                            .padding()
                    }
                            
                    else {
                        ProgressView()
                            .padding(.top, 15)
                        Text("Loading Menu...")
                            .foregroundStyle(Color.gray)
                    }
                    
                }
                

                Spacer()
            } .onAppear{
                fetchData()
                fetchRemainingBudget()
                loadCustomItems()
            }

        }.navigationBarTitleDisplayMode(.inline)
        .toolbar {
            NavigationLink(destination: Homepage()){
                HStack{
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

// MARK: - AI Recommendations Sheet

struct AIRecommendationsSheet: View {
    @ObservedObject var aiService: AIService
    let diningHall: String

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if aiService.isLoading {
                        HStack {
                            Spacer()
                            VStack(spacing: 12) {
                                ProgressView()
                                Text("Analyzing menu…")
                                    .foregroundStyle(Color.gray)
                                    .font(.subheadline)
                            }
                            .padding(.top, 40)
                            Spacer()
                        }
                    } else if let err = aiService.errorMessage {
                        Text(err)
                            .foregroundStyle(Color.red)
                            .padding()
                    } else if let s = aiService.suggestion {
                        // Summary
                        Text(s.summary)
                            .font(.subheadline)
                            .foregroundStyle(Color.secondary)
                            .padding(.horizontal)

                        // Recommended items
                        if !s.recommendedItems.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(s.recommendedItems, id: \.name) { item in
                                    HStack(alignment: .top, spacing: 12) {
                                        Image(systemName: "fork.knife")
                                            .foregroundStyle(Color.mBlue)
                                            .frame(width: 20)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(item.name)
                                                .font(.system(size: 15, weight: .semibold))
                                            Text(item.reason)
                                                .font(.caption)
                                                .foregroundStyle(Color.gray)
                                        }
                                        Spacer()
                                        Text("\(item.calories) cal")
                                            .font(.caption)
                                            .foregroundStyle(Color.mBlue)
                                            .fontWeight(.semibold)
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 10)
                                    Divider().padding(.leading, 52)
                                }
                            }
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                            .padding(.horizontal)
                        }
                    } else {
                        Text("Tap the sparkle button to get recommendations.")
                            .foregroundStyle(Color.gray)
                            .padding()
                    }
                }
                .padding(.top, 8)
            }
            .navigationTitle("What should I get?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text(diningHall.replacingOccurrences(of: " Dining Hall", with: ""))
                        .font(.caption)
                        .foregroundStyle(Color.gray)
                }
            }
        }
    }
}

struct SpecialViewer: View {
    @State var mealAddingTo: String
    @State private var menu: Menu? // Store the fetched menu data
    @Binding var selectedItems: Set<String>
    @State var selectedMeal = "Breakfast"
    @State var jsonBug = false
    @State var hallChanging = false
    @EnvironmentObject var toggleManager: ToggleManager
    @State private var quantities: [String: String] = [:]
    @Binding var addToMealButtonPressed: Bool





    func loadSpecialData() {
        guard let path = Bundle.main.path(forResource: "special_menu", ofType: "json") else {
            print("Special JSON file not found.")
            return
        }
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            //print(path)
            let decoder = JSONDecoder()
            let itemFeed = try decoder.decode(apiCalled.self, from: data)

            
            //print raw json
            //if let jsonString = String(data: data, encoding: .utf8) {
                //print("JSON Response: \(jsonString)")
            //}
            //let customMeal1 = Meal()
            

            self.menu = itemFeed.menu
            
            print("Demo data loaded successfully.")
            hallChanging = false
        } catch {
            print("Error loading demo data: \(error)")
        }
    }
    
    //api call
    func fetchData() {
        loadSpecialData()

    }
    
    func getCurrentDate() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd" // Set the format to include only year, month, and day
        let currentDate = Date()
        return dateFormatter.string(from: currentDate)
    }
    
    func saveSelectedItemsToDatabase() {
        guard let meals = menu?.meal else { return }
        print(getCurrentDate())
        print(selectedItems)
        
        // Find or create the meal in the database and get its ID
        do {
            try DatabaseManager.addMeal(date: getCurrentDate(), mealName: mealAddingTo) // Example date, use current date dynamically if needed.
            
            // Get the last inserted meal ID (or you might need to fetch it based on date and meal name)
            let mealID = try dbQueue.read { db in
                try Int.fetchOne(db, sql: "SELECT id FROM meals WHERE date = ? AND mealname = ?", arguments: [getCurrentDate(), mealAddingTo])
            }
            
            
            guard let validMealID = mealID else { return }
            
            var addedItems = Set<String>()  // A Set to track added items (by their name)

            for selectedItem in selectedItems {
                print(selectedItem)
                
                for meal in meals {
                    print(meal)
                    if let courses = meal.course?.courseitem {
                        for course in courses {
                            
                            // Find the first matching item
                            if let item = course.menuitem.item.first(where: { $0.name == selectedItem }) {
                                
                                // Check if this item has already been added
                                if addedItems.contains(selectedItem) {
                                    continue  // Skip if already added
                                }
                                
                                // Mark this item as added
                                addedItems.insert(selectedItem)
                                
                                // If nutrition exists, add the food item to the database
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

            
            print("SPECIAL ITEMS successfully added to the database.")
        } catch {
            print("Failed to add items: \(error)")
        }
    }

    
    
    
    //Structs for JSON decoding
    struct apiCalled: Codable {
        var menu: Menu?
    }
    struct Menu: Codable {
        var meal: [Meal]?
    }
    struct Meal: Codable {
        var name: String?
        var course: CourseWrapper?
        
        struct CourseWrapper: Codable {
            var courseitem: [Course] //makes an array called courseitem to store all courses for the meal (whether it be single or mutliple)
            
            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let singleCourseItem = try? container.decode(Course.self) {
                    // If a single MenuItem is decoded, add it to the array
                    courseitem = [singleCourseItem]
                } else if let multipleItems = try? container.decode([Course].self) {
                    // If an array of MenuItem is decoded, assign it
                    courseitem = multipleItems
                } else {
                    throw DecodingError.typeMismatch(
                        CourseWrapper.self,
                        DecodingError.Context(
                            codingPath: decoder.codingPath,
                            debugDescription: "Expected single MenuItem or array of MenuItem."
                        )
                    )
                }
            }
            //array vs single item decoding for menuitem
            struct Course: Codable {
                var name: String?
                var menuitem: ItemWrapper
                
                struct ItemWrapper: Codable {
                    var item: [MenuItem]
                    
                    init(from decoder: Decoder) throws {
                        let container = try decoder.singleValueContainer()
                        if let singleItem = try? container.decode(MenuItem.self) {
                            // If a single MenuItem is decoded, add it to the array
                            item = [singleItem]
                        } else if let multipleItems = try? container.decode([MenuItem].self) {
                            // If an array of MenuItem is decoded, assign it
                            item = multipleItems
                        } else {
                            throw DecodingError.typeMismatch(
                                ItemWrapper.self,
                                DecodingError.Context(
                                    codingPath: decoder.codingPath,
                                    debugDescription: "Expected single MenuItem or array of MenuItem."
                                )
                            )
                        }
                    }
                    
                    func encode(to encoder: Encoder) throws {
                        var container = encoder.singleValueContainer()
                        if item.count == 1 {
                            try container.encode(item[0]) // Encode as a single item if there's only one
                        } else {
                            try container.encode(item) // Encode as an array if there are multiple items
                        }
                    }
                }
                
                struct MenuItem: Codable {
                    var name: String?
                    var itemsize: ItemSize? //added

                    
                    
                }
            }
            //end of array vs single item decoding
        }
    }
    
    
    

    
    
    // Struct for Nutrition (only 4 macros)
    struct Nutrition: Codable {
        var pro: String?  // Protein
        var fat: String?  // Fat
        var cho: String?  // Carbohydrates
        var kcal: String? // Calories
        
        // Initialize with default values
        init(from nutritionDict: [String: String]? = nil) {
            self.pro = nutritionDict?["pro"] ?? "0gm"
            self.fat = nutritionDict?["fat"] ?? "0gm"
            self.cho = nutritionDict?["cho"] ?? "0gm"
            self.kcal = nutritionDict?["kcal"] ?? "0kcal"
        }
    }

    // Struct for ItemSize, including Nutrition
    struct ItemSize: Codable {
        var serving_size: String?   // Optional, in case it's missing
        var portion_size: String?  // Optional, in case it's missing
        var nutrition: Nutrition?  // Optional, in case it's missing or malformed
        
        enum CodingKeys: String, CodingKey {
            case serving_size
            case portion_size
            case nutrition
        }
        
        // Custom initializer to handle the case where `nutrition` might be an empty array
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.serving_size = try? container.decode(String.self, forKey: .serving_size)
            self.portion_size = try? container.decode(String.self, forKey: .portion_size)
            
            // Attempt to decode `nutrition` as a dictionary
            if let nutritionDict = try? container.decode([String: String].self, forKey: .nutrition) {
                self.nutrition = Nutrition(from: nutritionDict)
            } else if let nutritionArray = try? container.decode([String].self, forKey: .nutrition), nutritionArray.isEmpty {
                // If `nutrition` is an empty array, initialize it with default values
                self.nutrition = Nutrition()
            } else {
                // Default to empty nutrition if unable to decode
                self.nutrition = Nutrition()
            }
        }
    }

    
    
    

    

    var body: some View {

            VStack{
                ScrollView{
                    if let meals = menu?.meal{
                        if hallChanging == false{
                            ForEach(meals, id: \.name) { meal in
                                
                                if meal.course != nil {
                                    
                                    Text(meal.name?.lowercased().capitalized ?? "Unnamed Meal")
                                        
                                        .font(.largeTitle)
                                        .bold()
                                        .foregroundStyle(Color.white)
                                        .frame(width: 340, height: 60)
                                        .padding(.horizontal) // Add padding around the text
                                        .background(Color(.mBlue)) // Light gray background
                                        .cornerRadius(13) // Apply rounded corners
                                        
                                        .padding(.bottom, 8)
                                    
                                    
                                    
                                    
                                    
                                }
                                if let courses = meal.course?.courseitem {
                                    ForEach(courses, id: \.name) { course in
                                        VStack{
                                            HStack{
                                                Text(course.name ?? "Unnamed Course")
                                                    .foregroundStyle(Color.mmaize)
                                                    .font(.title3)
                                                    .fontWeight(.bold)
                                                    .padding(.leading, 15)
                                                //.underline(true)
                                                
                                                    .padding(.bottom, 4)
                                                    
                                                
                                                Spacer()
                                            }
                                            // Directly use `course.menuitem.item` without optional unwrapping
                                            
                                            ForEach(course.menuitem.item, id: \.name) { menuItem in
                                                
                                                VStack{
                                                    HStack{
                                                        Text(menuItem.name ?? "Unnamed MenuItem")
                                                            .font(. system(size: 14))
                                                            //.font(.title)
                                                            .padding(.leading, 15)
                                                            .fontWeight(.semibold)
                                                        
                                                        
                                                        
                                                        NavigationLink(destination: NutritionViewer(name: menuItem.name ?? "Unnamed MenuItem", kcal: menuItem.itemsize?.nutrition?.kcal ?? "0kcal", pro: menuItem.itemsize?.nutrition?.pro ?? "0gm", fat: menuItem.itemsize?.nutrition?.fat ?? "0gm", cho: menuItem.itemsize?.nutrition?.cho ?? "0gm", serving: menuItem.itemsize?.serving_size ?? "N/A")){
                                                            Image(systemName: "info.circle")
                                                                .resizable()
                                                                .frame(width: 17, height: 17)
                                                                
                                                            
                                                        }
                                                        Spacer()
                                                        if selectedItems.contains(menuItem.name ?? "") {
                                                            Picker("", selection: Binding(
                                                                get: { quantities[menuItem.name ?? ""] ?? "1" },
                                                                set: { quantities[menuItem.name ?? ""] = $0 }
                                                            )) {
                                                                ForEach(["0.5", "1", "2", "3", "4"], id: \.self) { q in
                                                                    Text(q).tag(q)
                                                                }
                                                                
                                                            }
                                                            
                                                            .accentColor(Color.primary)
                                                        }


                                                        
                                                        Toggle(isOn: Binding(
                                                            get: { selectedItems.contains(menuItem.name ?? "") },
                                                            set: { isSelected in
                                                                if isSelected {
                                                                    selectedItems.insert(menuItem.name ?? "")
                                                                } else {
                                                                    selectedItems.remove(menuItem.name ?? "")
                                                                }
                                                            }
                                                        )) {
                                                            
                                                            Image(systemName: selectedItems.contains(menuItem.name ?? "") ? "checkmark.square.fill" : "square") // Empty square when unselected, filled when selected
                                                                .foregroundStyle(Color.mBlue)
                                                                                             
                                                                .animation(nil, value:selectedItems)
                                                            //.frame(height:25)
                                                                .font(.title)
                                                                
                                                        }
                                                        .sensoryFeedback(.increase, trigger: selectedItems)
                                                        .labelsHidden()
                                                        .toggleStyle(.button)
                                                        .padding(.trailing, 15)
                                                        .buttonStyle(.plain)
                                                        // Show Picker only when the Toggle is checked

                                                        
                                                        
                                                        
                                                    }
                                                    Divider()
                                                }
                                            }
                                        }.padding(.bottom, 8)
                                    }
                                    
                                }
                            }
                        } else if jsonBug == true{
                            Text("Error fetching menus.\nPlease connect to the U-M Wifi.")
                                .foregroundStyle(Color.gray)
                                .padding()
                        }
                                
                        else {
                            ProgressView()
                                .padding(.top, 15)
                            Text("Loading Menu...")
                                .foregroundStyle(Color.gray)
                        }
                    } else if jsonBug == true{
                        Text("Error fetching menus.\nPlease connect to the U-M Wifi.")
                            .foregroundStyle(Color.gray)
                            .padding()
                    }
                            
                    else {
                        ProgressView()
                            .padding(.top, 15)
                        Text("Loading Menu...")
                            .foregroundStyle(Color.gray)
                    }
                    
                }

                Spacer()
            } .onAppear{fetchData()}
            .onChange(of:addToMealButtonPressed) {
                saveSelectedItemsToDatabase()
            }
        
        
            
        
        
            
        
    }
    

    
    
    
}


#Preview {
    Selector(mealAddingTo: "Breakfast")
    //SpecialViewer(mealAddingTo: "Breakfast")
}
