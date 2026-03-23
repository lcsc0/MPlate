//
//  AIService.swift
//  MaizePlate
//
//  Calls the Anthropic Claude API to generate daily meal tips and
//  dining hall item recommendations based on logged nutrition data.
//
//  API key is stored in UserDefaults under "anthropicApiKey".
//  Users add their key in the Settings tab.
//

import Foundation
import UIKit

// MARK: - Photo food item model

struct PhotoFoodItem: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let portionDescription: String
    let calories: Int
    let protein: Int
    let fat: Int
    let carbs: Int
    var isSelected: Bool = true
}

// MARK: - Output model

struct MealSuggestion {
    let summary: String
    let tips: [String]
    let recommendedItems: [RecommendedItem]

    struct RecommendedItem {
        let name: String
        let reason: String
        let calories: Int
        let portion: String   // e.g. "1 serving (180g)", "2 slices"
    }
}

// MARK: - Fix My Day output model

struct FixMyDayPlan {
    let analysis: String
    let mealBlocks: [MealBlock]

    struct MealBlock {
        let mealName: String          // e.g. "Dinner"
        let items: [PlannedItem]
        let blockCalories: Int
        let blockProtein: Int
        let blockFat: Int
        let blockCarbs: Int
    }

    struct PlannedItem {
        let name: String
        let portion: String
        let calories: Int
        let protein: Int
        let fat: Int
        let carbs: Int
        let reason: String
    }
}

// MARK: - Input model

struct AIMenuItem {
    let name: String
    let kcal: Int
    let protein: Int
    let fat: Int
    let carbs: Int
    let serving: String   // serving size string from menu, e.g. "1 cup", "3 oz"
}

// MARK: - What's Good Today output model

struct WhatsGoodItem: Identifiable {
    let id = UUID()
    let name: String
    let serving: String
    let calories: Int
    let protein: Int
    let fat: Int
    let carbs: Int
    let score: Int           // 1-10 rating for user's goals
    let reason: String
}

struct WhatsGoodResult {
    let summary: String
    let items: [WhatsGoodItem]
}

// MARK: - Service

@MainActor
class AIService: ObservableObject {
    @Published var isLoading = false
    @Published var suggestion: MealSuggestion?
    @Published var errorMessage: String?

    // MARK: - Fix My Day published state
    @Published var isFixMyDayLoading = false
    @Published var fixMyDayPlan: FixMyDayPlan?
    @Published var fixMyDayError: String?

    // MARK: - What's Good Today published state
    @Published var isWhatsGoodLoading = false
    @Published var whatsGoodResult: WhatsGoodResult?
    @Published var whatsGoodError: String?

    // MARK: - Photo analysis published state
    @Published var photoItems: [PhotoFoodItem] = []
    @Published var photoSummary: String = ""
    @Published var isPhotoAnalyzing: Bool = false
    @Published var photoError: String?

    private var apiKey: String {
        UserDefaults.standard.string(forKey: "anthropicApiKey") ?? ""
    }

    // MARK: Tracker suggestions — specific items from today's menu + other

    func getTrackerSuggestions(
        totalCalories: Int,
        totalProtein: Int,
        totalFat: Int,
        totalCarbs: Int,
        calorieGoal: Int,
        proteinGoal: Int,
        fatGoal: Int,
        carbGoal: Int,
        diningHall: String,
        menuItems: [AIMenuItem],
        healthGoals: String,
        refusedItems: [String] = [],
        mealPeriod: String = ""
    ) async {
        guard !apiKey.isEmpty else {
            errorMessage = "Add your Anthropic API key in Settings to enable AI suggestions."
            return
        }

        isLoading = true
        errorMessage = nil
        suggestion = nil

        let remaining    = max(0, calorieGoal  - totalCalories)
        let remainingPro = max(0, proteinGoal  - totalProtein)
        let remainingFat = max(0, fatGoal      - totalFat)
        let remainingCarb = max(0, carbGoal    - totalCarbs)
        let pct = calorieGoal > 0 ? Int(Double(totalCalories) / Double(calorieGoal) * 100) : 0

        let menuList: String
        if menuItems.isEmpty {
            menuList = "No menu data available."
        } else {
            menuList = menuItems.prefix(80).map {
                "\($0.name) | serving: \($0.serving) | \($0.kcal) cal | \($0.protein)g pro | \($0.fat)g fat | \($0.carbs)g carbs"
            }.joined(separator: "\n")
        }

        let goalsLine = healthGoals.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "None specified."
            : healthGoals

        let refusedSection = refusedItems.isEmpty
            ? "None."
            : refusedItems.joined(separator: "\n")

        let periodLine = mealPeriod.isEmpty ? "General (all-day)" : mealPeriod

        let userMessage = """
        Dining hall: \(diningHall)
        Current meal period: \(periodLine)
        User's health goals: \(goalsLine)

        Daily targets: \(calorieGoal) cal | \(proteinGoal)g protein | \(fatGoal)g fat | \(carbGoal)g carbs

        Items the user does NOT want suggested:
        \(refusedSection)

        Remaining budget: \(remaining) cal | \(remainingPro)g protein | \(remainingFat)g fat | \(remainingCarb)g carbs (\(pct)% of calorie goal used)

        Available items for this meal period (name | serving size | calories | protein | fat | carbs):
        \(menuList)

        Based on the user's health goals and the current meal period, recommend 3–5 specific items from the list above. Do NOT suggest refused items. Include exact portion and brief reason.
        """

        let systemPrompt = """
        You are a concise, personalized nutrition coach for a University of Michigan student eating in dining halls.
        Always consider the user's health goals and the current meal period.
        Recommend specific items from the EXACT list provided — do not invent items.
        Use item names EXACTLY as written. Each suggestion must include a concrete portion amount.
        Never suggest an item the user has refused.
        Respond with valid JSON only:
        {
          "summary": "one sentence tailored to the user's health goals and remaining budget",
          "tips": ["one brief tip relevant to their goals if applicable, otherwise empty array"],
          "recommendedItems": [
            {"name": "exact item name", "reason": "why + how much in under 12 words", "calories": 000, "portion": "e.g. 1 cup or 2 slices"}
          ]
        }
        No markdown in JSON values.
        """

        do {
            let raw = try await callClaude(system: systemPrompt, user: userMessage, maxTokens: 900)
            let cleaned = extractJSON(from: raw)
            if let data = cleaned.data(using: .utf8),
               let json = try? JSONDecoder().decode(RecommendationResponse.self, from: data) {
                let items = json.recommendedItems.map {
                    MealSuggestion.RecommendedItem(name: $0.name, reason: $0.reason, calories: $0.calories, portion: $0.portion ?? "1 serving")
                }
                suggestion = MealSuggestion(summary: json.summary, tips: json.tips, recommendedItems: items)
            } else {
                suggestion = MealSuggestion(summary: raw, tips: [], recommendedItems: [])
            }
        } catch {
            errorMessage = "AI error: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: Fix My Day — plan remaining meals to hit macro targets

    func getFixMyDayPlan(
        totalCalories: Int,
        totalProtein: Int,
        totalFat: Int,
        totalCarbs: Int,
        calorieGoal: Int,
        proteinGoal: Int,
        fatGoal: Int,
        carbGoal: Int,
        diningHall: String,
        menuItems: [AIMenuItem],
        healthGoals: String,
        mealsEaten: [String]   // e.g. ["Breakfast", "Lunch"]
    ) async {
        guard !apiKey.isEmpty else {
            fixMyDayError = "Add your Anthropic API key in Settings to enable AI suggestions."
            return
        }

        isFixMyDayLoading = true
        fixMyDayError = nil
        fixMyDayPlan = nil

        let remaining    = max(0, calorieGoal  - totalCalories)
        let remainingPro = max(0, proteinGoal  - totalProtein)
        let remainingFat = max(0, fatGoal      - totalFat)
        let remainingCarb = max(0, carbGoal    - totalCarbs)
        let pct = calorieGoal > 0 ? Int(Double(totalCalories) / Double(calorieGoal) * 100) : 0

        let eatenStr = mealsEaten.isEmpty ? "None yet" : mealsEaten.joined(separator: ", ")

        // Determine which meal periods remain
        let allPeriods = ["Breakfast", "Lunch", "Dinner"]
        let remaining_meals = allPeriods.filter { !mealsEaten.contains($0) }
        let remainingMealStr = remaining_meals.isEmpty ? "Only snacks/Other" : remaining_meals.joined(separator: ", ")

        let menuList: String
        if menuItems.isEmpty {
            menuList = "No menu data available."
        } else {
            menuList = menuItems.prefix(100).map {
                "\($0.name) | serving: \($0.serving) | \($0.kcal) cal | \($0.protein)g pro | \($0.fat)g fat | \($0.carbs)g carbs"
            }.joined(separator: "\n")
        }

        let goalsLine = healthGoals.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "None specified."
            : healthGoals

        let userMessage = """
        Dining hall: \(diningHall)
        User's health goals: \(goalsLine)

        Daily targets: \(calorieGoal) cal | \(proteinGoal)g protein | \(fatGoal)g fat | \(carbGoal)g carbs

        Already consumed today: \(totalCalories) cal | \(totalProtein)g protein | \(totalFat)g fat | \(totalCarbs)g carbs (\(pct)% of calorie goal used)
        Meals already logged: \(eatenStr)
        Remaining meals to plan: \(remainingMealStr)

        Remaining budget: \(remaining) cal | \(remainingPro)g protein | \(remainingFat)g fat | \(remainingCarb)g carbs

        Available items at \(diningHall) (name | serving size | calories | protein | fat | carbs):
        \(menuList)

        Create a concrete meal plan for the remaining meals (\(remainingMealStr)) using ONLY items from the list above. The plan should get as close to the daily targets as possible. Group items by meal period.
        """

        let systemPrompt = """
        You are a precision nutrition planner for a University of Michigan student. Your job is to "fix" the rest of their day by planning remaining meals that balance macros to hit daily targets.
        RULES:
        - Use ONLY items from the EXACT list provided. Do not invent items.
        - Use item names EXACTLY as written.
        - Group recommendations by meal period (e.g. Dinner, or Lunch + Dinner).
        - Each item must have a specific portion.
        - Aim to get within 5% of each macro target.
        - If the user has already exceeded a macro, minimize that macro in remaining meals.
        Respond with ONLY valid JSON:
        {
          "analysis": "1-2 sentence summary of what's off and how you're fixing it",
          "mealBlocks": [
            {
              "mealName": "Dinner",
              "items": [
                {"name": "exact item name", "portion": "1 cup", "calories": 200, "protein": 20, "fat": 5, "carbs": 15, "reason": "brief reason under 10 words"}
              ],
              "blockCalories": 600,
              "blockProtein": 45,
              "blockFat": 20,
              "blockCarbs": 55
            }
          ]
        }
        No markdown in JSON values.
        """

        do {
            let raw = try await callClaude(system: systemPrompt, user: userMessage, maxTokens: 1200)
            let cleaned = extractJSON(from: raw)
            if let data = cleaned.data(using: .utf8),
               let json = try? JSONDecoder().decode(FixMyDayResponse.self, from: data) {
                let blocks = json.mealBlocks.map { block in
                    FixMyDayPlan.MealBlock(
                        mealName: block.mealName,
                        items: block.items.map {
                            FixMyDayPlan.PlannedItem(
                                name: $0.name,
                                portion: $0.portion ?? "1 serving",
                                calories: $0.calories,
                                protein: $0.protein,
                                fat: $0.fat,
                                carbs: $0.carbs,
                                reason: $0.reason ?? ""
                            )
                        },
                        blockCalories: block.blockCalories,
                        blockProtein: block.blockProtein,
                        blockFat: block.blockFat,
                        blockCarbs: block.blockCarbs
                    )
                }
                fixMyDayPlan = FixMyDayPlan(analysis: json.analysis, mealBlocks: blocks)
            } else {
                fixMyDayPlan = FixMyDayPlan(analysis: raw, mealBlocks: [])
            }
        } catch {
            fixMyDayError = "AI error: \(error.localizedDescription)"
        }

        isFixMyDayLoading = false
    }

    // MARK: What's Good Today — rank menu items by user's goals

    func getWhatsGoodToday(
        menuItems: [AIMenuItem],
        calorieGoal: Int,
        proteinGoal: Int,
        fatGoal: Int,
        carbGoal: Int,
        healthGoals: String,
        diningHall: String,
        mealPeriod: String
    ) async {
        guard !apiKey.isEmpty else {
            whatsGoodError = "Add your Anthropic API key in Settings to enable AI suggestions."
            return
        }
        guard !menuItems.isEmpty else {
            whatsGoodError = "No menu items loaded yet."
            return
        }

        isWhatsGoodLoading = true
        whatsGoodError = nil
        whatsGoodResult = nil

        let menuList = menuItems.prefix(80).map {
            "\($0.name) | serving: \($0.serving) | \($0.kcal) cal | \($0.protein)g pro | \($0.fat)g fat | \($0.carbs)g carbs"
        }.joined(separator: "\n")

        let goalsLine = healthGoals.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "General health."
            : healthGoals

        let userMessage = """
        Dining hall: \(diningHall)
        Current meal period: \(mealPeriod)
        User's health goals: \(goalsLine)
        Daily targets: \(calorieGoal) cal | \(proteinGoal)g protein | \(fatGoal)g fat | \(carbGoal)g carbs

        Today's menu (name | serving | calories | protein | fat | carbs):
        \(menuList)

        Rank the top 8 best items from this menu for the user's goals. Score each 1-10. Focus on nutrient density, protein-to-calorie ratio, and alignment with their goals.
        """

        let systemPrompt = """
        You are a nutrition analyst for a University of Michigan dining hall app. Identify the BEST items on today's menu for the user's goals.
        Score each item 1-10 based on: protein density, calorie efficiency, micronutrient value, and goal alignment.
        Use ONLY items from the EXACT list provided. Use item names EXACTLY as written.
        Respond with ONLY valid JSON:
        {
          "summary": "1 sentence about today's menu quality for their goals",
          "items": [
            {"name": "exact item name", "serving": "1 cup", "calories": 200, "protein": 25, "fat": 5, "carbs": 10, "score": 9, "reason": "brief reason under 10 words"}
          ]
        }
        Order items from highest to lowest score. No markdown in JSON values.
        """

        do {
            let raw = try await callClaude(system: systemPrompt, user: userMessage, maxTokens: 1000)
            let cleaned = extractJSON(from: raw)
            if let data = cleaned.data(using: .utf8),
               let json = try? JSONDecoder().decode(WhatsGoodResponse.self, from: data) {
                let items = json.items.map {
                    WhatsGoodItem(
                        name: $0.name,
                        serving: $0.serving ?? "1 serving",
                        calories: $0.calories,
                        protein: $0.protein,
                        fat: $0.fat,
                        carbs: $0.carbs,
                        score: $0.score,
                        reason: $0.reason
                    )
                }
                whatsGoodResult = WhatsGoodResult(summary: json.summary, items: items)
            } else {
                whatsGoodResult = WhatsGoodResult(summary: raw, items: [])
            }
        } catch {
            whatsGoodError = "AI error: \(error.localizedDescription)"
        }

        isWhatsGoodLoading = false
    }

    // MARK: Dining recommendations (Selector tab sparkle button)

    func getDiningRecommendations(
        menuItems: [AIMenuItem],
        remainingCalories: Int,
        remainingProtein: Int,
        weightGoal: String
    ) async {
        guard !apiKey.isEmpty else {
            errorMessage = "Add your Anthropic API key in Settings to enable AI suggestions."
            return
        }
        guard !menuItems.isEmpty else {
            errorMessage = "No menu items loaded yet."
            return
        }

        isLoading = true
        errorMessage = nil
        suggestion = nil

        let menuList = menuItems.prefix(80).map {
            "\($0.name) | serving: \($0.serving) | \($0.kcal) cal | \($0.protein)g pro | \($0.fat)g fat | \($0.carbs)g carbs"
        }.joined(separator: "\n")

        let userMessage = """
        Remaining calories for today: \(remainingCalories)
        Remaining protein needed: \(remainingProtein)g
        Weight goal: \(weightGoal)

        Available items (name | serving | calories | protein | fat | carbs):
        \(menuList)

        Recommend the best 3–5 items from this exact list. Include exact portion sizes and a brief reason for each.
        """

        let systemPrompt = """
        You are a nutrition assistant for a University of Michigan dining hall app.
        Recommend specific items from the EXACT list provided. Do not invent items.
        Use item names EXACTLY as written.
        Respond with valid JSON only:
        {
          "summary": "brief one-sentence plan",
          "tips": [],
          "recommendedItems": [
            {"name": "exact item name", "reason": "why + portion in under 12 words", "calories": 000, "portion": "e.g. 1 cup"}
          ]
        }
        No markdown in JSON values.
        """

        do {
            let raw = try await callClaude(system: systemPrompt, user: userMessage, maxTokens: 900)
            let cleaned = extractJSON(from: raw)
            if let data = cleaned.data(using: .utf8),
               let json = try? JSONDecoder().decode(RecommendationResponse.self, from: data) {
                let items = json.recommendedItems.map {
                    MealSuggestion.RecommendedItem(name: $0.name, reason: $0.reason, calories: $0.calories, portion: $0.portion ?? "1 serving")
                }
                suggestion = MealSuggestion(summary: json.summary, tips: [], recommendedItems: items)
            } else {
                suggestion = MealSuggestion(summary: raw, tips: [], recommendedItems: [])
            }
        } catch {
            errorMessage = "AI error: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Private helpers

    private func callClaude(system: String, user: String, maxTokens: Int = 600) async throws -> String {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": maxTokens,
            "system": system,
            "messages": [["role": "user", "content": user]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        if http.statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? "unknown error"
            throw NSError(domain: "AIService", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "API error \(http.statusCode): \(body)"])
        }

        struct ClaudeResponse: Codable {
            struct Content: Codable { let text: String }
            let content: [Content]
        }
        let decoded = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        return decoded.content.first?.text ?? ""
    }

    private func extractJSON(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("```") {
            let lines = trimmed.components(separatedBy: "\n")
            let inner = lines.dropFirst().dropLast().joined(separator: "\n")
            return inner.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }

    // MARK: - Photo analysis

    func analyzeFoodPhoto(_ image: UIImage) async {
        guard !apiKey.isEmpty else {
            photoError = "Add your Anthropic API key in Settings to enable AI photo analysis."
            return
        }
        isPhotoAnalyzing = true
        photoError = nil
        photoItems = []
        photoSummary = ""

        guard let imageData = compressImage(image) else {
            photoError = "Could not compress image."
            isPhotoAnalyzing = false
            return
        }
        let base64 = imageData.base64EncodedString()

        let messages: [[String: Any]] = [[
            "role": "user",
            "content": [
                [
                    "type": "image",
                    "source": [
                        "type": "base64",
                        "media_type": "image/jpeg",
                        "data": base64
                    ]
                ],
                [
                    "type": "text",
                    "text": "Identify all food items visible. For each item estimate portion size using visual cues (plate size, utensils, standard portions) and provide nutritional info. Return ONLY valid JSON: {\"summary\": \"brief description\", \"items\": [{\"name\": \"food name\", \"portionDescription\": \"~180g / 1 cup\", \"calories\": 200, \"protein\": 30, \"fat\": 5, \"carbs\": 10}]}"
                ]
            ]
        ]]

        let system = "You are a precise food portion analyst. Estimate realistic nutrition values for what's visible. Be specific about portions. Only return valid JSON, no markdown."

        do {
            let raw = try await callClaudeVision(system: system, messages: messages, maxTokens: 900)
            parsePhotoResponse(raw)
        } catch {
            photoError = "AI error: \(error.localizedDescription)"
        }

        isPhotoAnalyzing = false
    }

    func analyzeBeforeAfterPhotos(before: UIImage, after: UIImage) async {
        guard !apiKey.isEmpty else {
            photoError = "Add your Anthropic API key in Settings to enable AI photo analysis."
            return
        }
        isPhotoAnalyzing = true
        photoError = nil
        photoItems = []
        photoSummary = ""

        guard let beforeData = compressImage(before),
              let afterData = compressImage(after) else {
            photoError = "Could not compress images."
            isPhotoAnalyzing = false
            return
        }

        let messages: [[String: Any]] = [[
            "role": "user",
            "content": [
                [
                    "type": "image",
                    "source": [
                        "type": "base64",
                        "media_type": "image/jpeg",
                        "data": beforeData.base64EncodedString()
                    ]
                ],
                [
                    "type": "image",
                    "source": [
                        "type": "base64",
                        "media_type": "image/jpeg",
                        "data": afterData.base64EncodedString()
                    ]
                ],
                [
                    "type": "text",
                    "text": "The first image shows a plate BEFORE eating. The second image shows the SAME plate AFTER eating. Compare them and estimate what was consumed (what's missing or reduced). Return ONLY valid JSON: {\"summary\": \"what was consumed\", \"items\": [{\"name\": \"food consumed\", \"portionDescription\": \"amount eaten e.g. ~120g / half portion\", \"calories\": 150, \"protein\": 20, \"fat\": 4, \"carbs\": 5}]}"
                ]
            ]
        ]]

        let system = "You are a precise food portion analyst. Estimate realistic nutrition values for what's visible. Be specific about portions. Only return valid JSON, no markdown."

        do {
            let raw = try await callClaudeVision(system: system, messages: messages, maxTokens: 900)
            parsePhotoResponse(raw)
        } catch {
            photoError = "AI error: \(error.localizedDescription)"
        }

        isPhotoAnalyzing = false
    }

    private func compressImage(_ image: UIImage, maxBytes: Int = 1_000_000) -> Data? {
        var quality: CGFloat = 0.7
        guard var data = image.jpegData(compressionQuality: quality) else { return nil }
        while data.count > maxBytes && quality > 0.1 {
            quality -= 0.1
            data = image.jpegData(compressionQuality: quality) ?? data
        }
        if data.count > maxBytes {
            // Scale down the image
            let scale = sqrt(Double(maxBytes) / Double(data.count))
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
            data = resized.jpegData(compressionQuality: 0.7) ?? data
        }
        return data
    }

    private func parsePhotoResponse(_ raw: String) {
        let cleaned = extractJSON(from: raw)
        guard let data = cleaned.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(PhotoResponse.self, from: data) else {
            photoError = "Could not parse AI response."
            return
        }
        photoSummary = decoded.summary
        photoItems = decoded.items.map {
            PhotoFoodItem(
                name: $0.name,
                portionDescription: $0.portionDescription,
                calories: $0.calories,
                protein: $0.protein,
                fat: $0.fat,
                carbs: $0.carbs
            )
        }
    }

    private func callClaudeVision(system: String, messages: [[String: Any]], maxTokens: Int = 900) async throws -> String {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": maxTokens,
            "system": system,
            "messages": messages
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        if http.statusCode != 200 {
            let bodyStr = String(data: data, encoding: .utf8) ?? "unknown error"
            throw NSError(domain: "AIService", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "API error \(http.statusCode): \(bodyStr)"])
        }

        struct ClaudeResponse: Codable {
            struct Content: Codable { let text: String }
            let content: [Content]
        }
        let decoded = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        return decoded.content.first?.text ?? ""
    }

    // MARK: - Codable response models

    private struct PhotoResponse: Codable {
        let summary: String
        let items: [Item]
        struct Item: Codable {
            let name: String
            let portionDescription: String
            let calories: Int
            let protein: Int
            let fat: Int
            let carbs: Int
        }
    }

    private struct RecommendationResponse: Codable {
        let summary: String
        let tips: [String]
        let recommendedItems: [Item]
        struct Item: Codable {
            let name: String
            let reason: String
            let calories: Int
            let portion: String?
        }
    }

    private struct FixMyDayResponse: Codable {
        let analysis: String
        let mealBlocks: [Block]
        struct Block: Codable {
            let mealName: String
            let items: [Item]
            let blockCalories: Int
            let blockProtein: Int
            let blockFat: Int
            let blockCarbs: Int
        }
        struct Item: Codable {
            let name: String
            let portion: String?
            let calories: Int
            let protein: Int
            let fat: Int
            let carbs: Int
            let reason: String?
        }
    }

    private struct WhatsGoodResponse: Codable {
        let summary: String
        let items: [Item]
        struct Item: Codable {
            let name: String
            let serving: String?
            let calories: Int
            let protein: Int
            let fat: Int
            let carbs: Int
            let score: Int
            let reason: String
        }
    }
}
