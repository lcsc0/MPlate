//
//  FoodSearchService.swift
//  M-Cals
//
//  Queries the USDA FoodData Central API to auto-fill nutrition when adding custom foods.
//  Free API key: https://fdc.nal.usda.gov/api-key-signup.html
//  DEMO_KEY works out of the box (30 req/hr, 50/day per IP).
//

import Foundation

struct FoodSearchResult: Identifiable {
    let id: Int
    let name: String
    let calories: Int
    let protein: Int
    let fat: Int
    let carbs: Int
    let servingSize: String
}

@MainActor
class FoodSearchService: ObservableObject {
    @Published var results: [FoodSearchResult] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var searchTask: Task<Void, Never>?

    // Replace with a personal free key from https://fdc.nal.usda.gov/api-key-signup.html
    private let apiKey = "DEMO_KEY"

    func search(query: String) {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            errorMessage = nil
            return
        }

        searchTask?.cancel()
        searchTask = Task {
            // 400ms debounce
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }

            isLoading = true
            errorMessage = nil

            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            let urlStr = "https://api.nal.usda.gov/fdc/v1/foods/search?query=\(encoded)&dataType=Survey%20%28FNDDS%29,SR%20Legacy&pageSize=12&api_key=\(apiKey)"

            guard let url = URL(string: urlStr) else {
                isLoading = false
                return
            }

            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let response = try JSONDecoder().decode(USDASearchResponse.self, from: data)

                let mapped: [FoodSearchResult] = response.foods.compactMap { food in
                    // Build a nutrientId → value map
                    var nutrientMap: [Int: Double] = [:]
                    for n in food.foodNutrients {
                        if let nid = n.nutrientId, let val = n.value {
                            nutrientMap[nid] = val
                        }
                    }
                    // Nutrient IDs: 1008 = kcal, 1003 = protein, 1004 = fat, 1005 = carbs
                    let cal  = Int(nutrientMap[1008] ?? 0)
                    let pro  = Int(nutrientMap[1003] ?? 0)
                    let fat  = Int(nutrientMap[1004] ?? 0)
                    let carb = Int(nutrientMap[1005] ?? 0)

                    let serving: String
                    if let size = food.servingSize, let unit = food.servingSizeUnit {
                        serving = "\(Int(size))\(unit)"
                    } else {
                        serving = "100g"
                    }

                    return FoodSearchResult(
                        id: food.fdcId,
                        name: food.description.prefix(1).uppercased() + food.description.dropFirst().lowercased(),
                        calories: cal,
                        protein: pro,
                        fat: fat,
                        carbs: carb,
                        servingSize: serving
                    )
                }

                results = mapped
                isLoading = false
            } catch {
                errorMessage = "Search unavailable. Enter manually."
                results = []
                isLoading = false
            }
        }
    }

    func clear() {
        searchTask?.cancel()
        results = []
        errorMessage = nil
        isLoading = false
    }
}

// MARK: - USDA JSON models

private struct USDASearchResponse: Codable {
    let foods: [USDAFood]
}

private struct USDAFood: Codable {
    let fdcId: Int
    let description: String
    let foodNutrients: [USDANutrient]
    let servingSize: Double?
    let servingSizeUnit: String?
}

private struct USDANutrient: Codable {
    let nutrientId: Int?
    let value: Double?
}
