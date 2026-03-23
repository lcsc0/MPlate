//
//  DatabaseManager.swift
//  MPlate
//

import Foundation
import GRDB

var dbQueue: DatabaseQueue!

class DatabaseManager {

    static func setup() throws {
        let databaseURL = try FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("datab14.sqlite")

        dbQueue = try DatabaseQueue(path: databaseURL.path)

        try dbQueue.write { db in
            try db.create(table: "meals", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("date", .text).notNull()
                t.column("mealname", .text).notNull()
            }
        }

        try dbQueue.write { db in
            try db.create(table: "fooditems", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("meal_id", .integer).notNull()
                    .references("meals", onDelete: .cascade)
                t.column("name", .text).notNull()
                t.column("kcal", .text).notNull()
                t.column("pro", .text).notNull()
                t.column("fat", .text).notNull()
                t.column("cho", .text).notNull()
                t.column("serving", .text).notNull()
                t.column("qty", .text).notNull()
            }
        }

        try dbQueue.write { db in
            try db.create(table: "user", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("weightplan", .text).notNull()
                t.column("caloriegoal", .integer).notNull()
                t.column("firstSetupComplete", .boolean).notNull()
            }
        }

        try dbQueue.write { db in
            try db.create(table: "customitems3", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("kcal", .text).notNull()
                t.column("pro", .text).notNull()
                t.column("fat", .text).notNull()
                t.column("cho", .text).notNull()
                t.column("serving", .text).notNull()
                t.column("created_at", .date).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                print("customitems3 database is good.")
            }
        }

        // Migrate fooditems: add extended nutrient columns if they don't exist yet
        let extraColumns: [(String, String)] = [
            ("fiber", "0gm"), ("sodium", "0mg"), ("sugar", "0gm"),
            ("sat_fat", "0gm"), ("cholesterol", "0mg"), ("calcium", "0mg"),
            ("iron", "0mg"), ("vit_c", "0mg"), ("vit_d", "0mcg"), ("potassium", "0mg")
        ]
        for (col, def) in extraColumns {
            try? dbQueue.write { db in
                try db.execute(sql: "ALTER TABLE fooditems ADD COLUMN \(col) TEXT NOT NULL DEFAULT '\(def)'")
            }
        }

        // Weight log table
        try dbQueue.write { db in
            try db.create(table: "weight_log", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("date", .text).notNull().unique()
                t.column("weight", .double).notNull()  // lbs
            }
        }

        // Adaptive TDEE toggle column on user table
        try? dbQueue.write { db in
            try db.execute(sql: "ALTER TABLE user ADD COLUMN adaptive_tdee INTEGER NOT NULL DEFAULT 0")
        }
    }

    // MARK: - Basic writes

    static func addMeal(date: String, mealName: String) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "INSERT INTO meals (date, mealname) VALUES (?, ?)",
                arguments: [date, mealName]
            )
        }
    }

    static func addFoodItem(
        meal_id: Int, name: String,
        kcal: String, pro: String, fat: String, cho: String,
        serving: String, qty: String,
        fiber: String = "0gm", sodium: String = "0mg", sugar: String = "0gm",
        satFat: String = "0gm", cholesterol: String = "0mg",
        calcium: String = "0mg", iron: String = "0mg",
        vitC: String = "0mg", vitD: String = "0mcg", potassium: String = "0mg"
    ) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO fooditems
                (meal_id, name, kcal, pro, fat, cho, serving, qty,
                 fiber, sodium, sugar, sat_fat, cholesterol, calcium, iron, vit_c, vit_d, potassium)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [meal_id, name, kcal, pro, fat, cho, serving, qty,
                            fiber, sodium, sugar, satFat, cholesterol, calcium, iron, vitC, vitD, potassium]
            )
        }
    }

    static func addCustomItem(name: String, kcal: String, pro: String, fat: String, cho: String, serving: String) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "INSERT INTO customitems3 (name, kcal, pro, fat, cho, serving) VALUES (?, ?, ?, ?, ?, ?)",
                arguments: [name, kcal, pro, fat, cho, serving]
            )
            print("the custom sql ran")
        }
    }

    // MARK: - Date helper

    static func getCurrentDate() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter.string(from: Date())
    }

    // MARK: - User queries

    static func checkFirstSetupComplete() -> Int64 {
        do {
            return try dbQueue.read { db in
                let result = try Row.fetchOne(db, sql: "SELECT firstSetupComplete FROM user WHERE id = 1")
                if let result = result, let val = result["firstSetupComplete"] {
                    return val as! Int64
                }
                return 0
            }
        } catch {
            print("Error fetching firstSetupComplete: \(error)")
            return 0
        }
    }

    static func initDefaultUser() {
        do {
            try dbQueue.write { db in
                let rowCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM user") ?? 0
                if rowCount == 0 {
                    try db.execute(
                        sql: "INSERT INTO user (weightplan, caloriegoal, firstSetupComplete) VALUES ('maintain', 2000, false)"
                    )
                    print("Default user values initialized.")
                } else {
                    print("User table already has entries; skipping initialization.")
                }
            }
        } catch {
            print("Error initializing default user values: \(error)")
        }
    }

    static func setCalorieGoal(_ goal: Int64) {
        do {
            try dbQueue.write { db in
                try db.execute(sql: "UPDATE user SET caloriegoal = ? WHERE id = 1", arguments: [goal])
            }
        } catch {
            print("Error updating caloriegoal: \(error)")
        }
    }

    static func getCurrentCalorieGoal() -> Int64 {
        do {
            return try dbQueue.read { db in
                let result = try Row.fetchOne(db, sql: "SELECT caloriegoal FROM user WHERE id = 1")
                if let result = result, let goal = result["caloriegoal"] {
                    return goal as! Int64
                }
                return 2000
            }
        } catch {
            print("Error fetching caloriegoal: \(error)")
            return 2000
        }
    }

    // MARK: - Food item queries

    static func getFoodItemsForMeal(date: String, mealname: String, completion: @escaping ([FoodItem]) -> Void) {
        do {
            try dbQueue.read { db in
                let query = """
                SELECT fooditems.*
                FROM meals
                JOIN fooditems ON fooditems.meal_id = meals.id
                WHERE meals.date = ? AND meals.mealname = ?
                """
                let fetchedItems = try Row.fetchAll(db, sql: query, arguments: [date, mealname])
                let foodItems = fetchedItems.map { row in
                    FoodItem(
                        id: row["id"] as! Int64,
                        name: row["name"] as! String,
                        kcal: row["kcal"] as! String,
                        pro: row["pro"] as! String,
                        fat: row["fat"] as! String,
                        cho: row["cho"] as! String,
                        serving: row["serving"] as! String,
                        qty: row["qty"] as! String,
                        fiber: (row["fiber"] as? String) ?? "0gm",
                        sodium: (row["sodium"] as? String) ?? "0mg",
                        sugar: (row["sugar"] as? String) ?? "0gm",
                        satFat: (row["sat_fat"] as? String) ?? "0gm",
                        cholesterol: (row["cholesterol"] as? String) ?? "0mg",
                        calcium: (row["calcium"] as? String) ?? "0mg",
                        iron: (row["iron"] as? String) ?? "0mg",
                        vitC: (row["vit_c"] as? String) ?? "0mg",
                        vitD: (row["vit_d"] as? String) ?? "0mcg",
                        potassium: (row["potassium"] as? String) ?? "0mg"
                    )
                }
                completion(foodItems)
            }
        } catch {
            print("Error fetching food items: \(error.localizedDescription)")
        }
    }

    static func deleteFoodItem(id: Int64) {
        do {
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM fooditems WHERE id = ?", arguments: [id])
            }
        } catch {
            print("Error deleting food item: \(error.localizedDescription)")
        }
    }

    // MARK: - Calorie trend

    static func loadCalorieTrend(days: Int) -> [DayCalories] {
        do {
            let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            let cutoffStr = f.string(from: cutoff)

            let rows = try dbQueue.read { db -> [(String, String, String)] in
                let query = """
                SELECT m.date, fi.kcal, fi.qty
                FROM fooditems fi
                JOIN meals m ON fi.meal_id = m.id
                WHERE m.date >= ?
                ORDER BY m.date
                """
                return try Row.fetchAll(db, sql: query, arguments: [cutoffStr]).map { row in
                    (row["date"] as! String, row["kcal"] as! String, row["qty"] as! String)
                }
            }
            var dateTotals: [String: Int] = [:]
            for (date, kcal, qty) in rows {
                let kcalStr = kcal.replacingOccurrences(of: "kcal", with: "").trimmingCharacters(in: .whitespaces)
                let kcalVal = Double(kcalStr) ?? 0
                let qtyVal = Double(qty) ?? 1
                dateTotals[date, default: 0] += Int(kcalVal * qtyVal)
            }
            return dateTotals.sorted(by: { $0.key < $1.key }).map {
                DayCalories(date: $0.key, calories: $0.value)
            }
        } catch {
            print("Error loading calorie trend: \(error)")
            return []
        }
    }

    // MARK: - Remaining budget (for AI recommendations)

    static func fetchRemainingBudget() -> (calories: Int, protein: Int, weightGoal: String) {
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
            return (max(0, calorieGoal - totalKcal), max(0, 150 - totalPro), wGoal)
        } catch {
            print("fetchRemainingBudget error: \(error)")
            return (0, 0, "maintain")
        }
    }

    // MARK: - Custom items

    static func loadCustomItems() -> [CustomItemRow] {
        do {
            return try dbQueue.read { db in
                let rows = try Row.fetchAll(db, sql: "SELECT id, name, kcal, pro, fat, cho, serving FROM customitems3 ORDER BY created_at DESC")
                return rows.map { row in
                    CustomItemRow(
                        id: row["id"],
                        name: row["name"],
                        kcal: row["kcal"],
                        pro: row["pro"],
                        fat: row["fat"],
                        cho: row["cho"],
                        serving: row["serving"]
                    )
                }
            }
        } catch {
            print("Error loading custom items: \(error)")
            return []
        }
    }

    static func fetchPastItems() -> [FoodItem] {
        do {
            return try dbQueue.read { db in
                let rows = try Row.fetchAll(db, sql: "SELECT * FROM customitems3 ORDER BY id DESC")
                return rows.map { row in
                    FoodItem(
                        id: row["id"],
                        name: row["name"],
                        kcal: row["kcal"],
                        pro: row["pro"],
                        fat: row["fat"],
                        cho: row["cho"],
                        serving: row["serving"],
                        qty: "1",
                        fiber: "0gm",
                        sodium: "0mg",
                        sugar: "0gm",
                        satFat: "0gm",
                        cholesterol: "0mg",
                        calcium: "0mg",
                        iron: "0mg",
                        vitC: "0mg",
                        vitD: "0mcg",
                        potassium: "0mg"
                    )
                }
            }
        } catch {
            print("Error fetching past items: \(error)")
            return []
        }
    }

    static func removeCustomItem(id: Int64) {
        do {
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM customitems3 WHERE id = ?", arguments: [id])
            }
            print("Item \(id) removed from customitems3.")
        } catch {
            print("Failed to remove item \(id): \(error)")
        }
    }

    // MARK: - Meal ID helper

    static func getOrCreateMealID(date: String, mealName: String) throws -> Int {
        try addMeal(date: date, mealName: mealName)
        let mealID = try dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT id FROM meals WHERE date = ? AND mealname = ?", arguments: [date, mealName])
        }
        guard let validMealID = mealID else {
            throw NSError(domain: "DatabaseManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not find meal ID"])
        }
        return validMealID
    }

    // MARK: - Weight logging

    static func logWeight(date: String, weight: Double) {
        do {
            try dbQueue.write { db in
                try db.execute(
                    sql: """
                    INSERT INTO weight_log (date, weight) VALUES (?, ?)
                    ON CONFLICT(date) DO UPDATE SET weight = excluded.weight
                    """,
                    arguments: [date, weight]
                )
            }
        } catch {
            print("Error logging weight: \(error)")
        }
    }

    static func getWeightForDate(_ date: String) -> Double? {
        do {
            return try dbQueue.read { db in
                try Double.fetchOne(db, sql: "SELECT weight FROM weight_log WHERE date = ?", arguments: [date])
            }
        } catch {
            print("Error fetching weight: \(error)")
            return nil
        }
    }

    static func deleteWeight(date: String) {
        do {
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM weight_log WHERE date = ?", arguments: [date])
            }
        } catch {
            print("Error deleting weight: \(error)")
        }
    }

    static func loadWeightTrend(days: Int) -> [WeightEntry] {
        do {
            let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            let cutoffStr = f.string(from: cutoff)
            return try dbQueue.read { db in
                let rows = try Row.fetchAll(db,
                    sql: "SELECT id, date, weight FROM weight_log WHERE date >= ? ORDER BY date",
                    arguments: [cutoffStr])
                return rows.map { row in
                    WeightEntry(id: row["id"], date: row["date"], weight: row["weight"])
                }
            }
        } catch {
            print("Error loading weight trend: \(error)")
            return []
        }
    }

    // MARK: - Adaptive TDEE

    static func isAdaptiveTDEEEnabled() -> Bool {
        do {
            return try dbQueue.read { db in
                let row = try Row.fetchOne(db, sql: "SELECT adaptive_tdee FROM user WHERE id = 1")
                return (row?["adaptive_tdee"] as? Int64 ?? 0) != 0
            }
        } catch { return false }
    }

    static func setAdaptiveTDEE(_ enabled: Bool) {
        do {
            try dbQueue.write { db in
                try db.execute(sql: "UPDATE user SET adaptive_tdee = ? WHERE id = 1", arguments: [enabled ? 1 : 0])
            }
        } catch {
            print("Error setting adaptive TDEE: \(error)")
        }
    }

    /// Recalculates and applies the adaptive calorie goal if enabled.
    /// Returns the new goal if it was adjusted, nil otherwise.
    @discardableResult
    static func applyAdaptiveGoalIfNeeded() -> Int? {
        guard isAdaptiveTDEEEnabled() else { return nil }

        let weights = loadWeightTrend(days: 28)
        let calories = loadCalorieTrend(days: 28)

        guard let actualTDEE = AdaptiveTDEE.calculate(weights: weights, dailyCalories: calories) else {
            return nil
        }

        // Get current weight plan
        let weightPlan: String
        do {
            weightPlan = try dbQueue.read { db in
                let row = try Row.fetchOne(db, sql: "SELECT weightplan FROM user WHERE id = 1")
                return (row?["weightplan"] as? String) ?? "maintain"
            }
        } catch {
            return nil
        }

        let newGoal = AdaptiveTDEE.suggestedGoal(actualTDEE: actualTDEE, weightPlan: weightPlan)
        setCalorieGoal(Int64(newGoal))
        return newGoal
    }
}
