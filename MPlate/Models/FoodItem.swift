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
}

// MARK: - Nutrient calculation

extension Array where Element == FoodItem {
    func totalNutrient(key: String) -> Int {
        var total = 0
        for item in self {
            let nutrientValue: String
            let qty = Double(item.qty) ?? 1

            switch key {
            case "kcal":
                nutrientValue = String(item.kcal.dropLast(4))
            case "pro":
                nutrientValue = String(item.pro.dropLast(2))
            case "fat":
                nutrientValue = String(item.fat.dropLast(2))
            case "cho":
                nutrientValue = String(item.cho.dropLast(2))
            default:
                nutrientValue = "0"
            }

            if let nutrientDoubValue = Double(nutrientValue.trimmingCharacters(in: .whitespaces)) {
                total += Int(nutrientDoubValue * qty)
            } else {
                print("Invalid \(key) value: \(nutrientValue)")
            }
        }
        return total
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
