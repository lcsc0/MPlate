//
//  FoodItem.swift
//  MPlate
//

import Foundation

struct FoodItem: Identifiable {
    let id: Int64
    let name: String
    let kcal: String
    let pro: String
    let fat: String
    let cho: String
    let serving: String
    let qty: String
    let fiber: String       // "4gm"
    let sodium: String      // "3mg"
    let sugar: String       // "0gm"
    let satFat: String      // "1gm"
    let cholesterol: String // "0mg"
    let calcium: String     // "23mg"
    let iron: String        // "2mg"
    let vitC: String        // "0mg"
    let vitD: String        // "0mcg"
    let potassium: String   // "157mg"
}

// MARK: - Nutrient calculation

func parseNutrientValue(_ s: String) -> Double {
    let digits = s.prefix(while: { $0.isNumber || $0 == "." })
    return Double(digits) ?? 0
}

extension Array where Element == FoodItem {
    func totalNutrient(key: String) -> Int {
        var total = 0.0
        for item in self {
            let qty = Double(item.qty) ?? 1
            let raw: Double
            switch key {
            case "kcal":        raw = parseNutrientValue(item.kcal)
            case "pro":         raw = parseNutrientValue(item.pro)
            case "fat":         raw = parseNutrientValue(item.fat)
            case "cho":         raw = parseNutrientValue(item.cho)
            case "fiber":       raw = parseNutrientValue(item.fiber)
            case "sodium":      raw = parseNutrientValue(item.sodium)
            case "sugar":       raw = parseNutrientValue(item.sugar)
            case "satFat":      raw = parseNutrientValue(item.satFat)
            case "cholesterol": raw = parseNutrientValue(item.cholesterol)
            case "calcium":     raw = parseNutrientValue(item.calcium)
            case "iron":        raw = parseNutrientValue(item.iron)
            case "vitC":        raw = parseNutrientValue(item.vitC)
            case "vitD":        raw = parseNutrientValue(item.vitD)
            case "potassium":   raw = parseNutrientValue(item.potassium)
            default:            raw = 0
            }
            total += raw * qty
        }
        return Int(total)
    }
}

func GetTotalNutrient(bitems: [FoodItem] = [], litems: [FoodItem] = [], ditems: [FoodItem] = [], oitems: [FoodItem] = [], nutrientKey: String) -> Int {
    return bitems.totalNutrient(key: nutrientKey)
         + litems.totalNutrient(key: nutrientKey)
         + ditems.totalNutrient(key: nutrientKey)
         + oitems.totalNutrient(key: nutrientKey)
}

func formatNumberWithCommas(_ number: Int) -> String? {
    let numberFormatter = NumberFormatter()
    numberFormatter.numberStyle = .decimal
    return numberFormatter.string(from: NSNumber(value: number))
}
