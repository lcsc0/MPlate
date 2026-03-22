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

// MARK: - Input model

struct AIMenuItem {
    let name: String
    let kcal: Int
    let protein: Int
    let fat: Int
    let carbs: Int
    let serving: String   // serving size string from menu, e.g. "1 cup", "3 oz"
}

// MARK: - Service

@MainActor
class AIService: ObservableObject {
    @Published var isLoading = false
    @Published var suggestion: MealSuggestion?
    @Published var errorMessage: String?

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
        diningHall: String,
        menuItems: [AIMenuItem]
    ) async {
        guard !apiKey.isEmpty else {
            errorMessage = "Add your Anthropic API key in Settings to enable AI suggestions."
            return
        }

        isLoading = true
        errorMessage = nil
        suggestion = nil

        let remaining = max(0, calorieGoal - totalCalories)
        let remainingPro = max(0, 150 - totalProtein)
        let pct = calorieGoal > 0 ? Int(Double(totalCalories) / Double(calorieGoal) * 100) : 0

        let menuList: String
        if menuItems.isEmpty {
            menuList = "No menu data available."
        } else {
            menuList = menuItems.prefix(80).map {
                "\($0.name) | serving: \($0.serving) | \($0.kcal) cal | \($0.protein)g pro | \($0.fat)g fat | \($0.carbs)g carbs"
            }.joined(separator: "\n")
        }

        let userMessage = """
        Dining hall: \(diningHall)

        Today's nutrition so far:
        - Calories: \(totalCalories) / \(calorieGoal) (\(pct)% of goal, \(remaining) cal remaining)
        - Protein: \(totalProtein)g (approx \(remainingPro)g still needed)
        - Fat: \(totalFat)g
        - Carbs: \(totalCarbs)g

        Available items today (name | serving size | calories | protein | fat | carbs):
        \(menuList)

        Recommend 3–5 specific items from the list above that best fill my remaining \(remaining) calories and \(remainingPro)g protein. Include exactly how much to eat (e.g. "1 serving", "2 scoops") and why.
        """

        let systemPrompt = """
        You are a concise nutrition coach for a University of Michigan student eating in dining halls today.
        Recommend specific items from the EXACT list provided — do not invent items.
        Use item names EXACTLY as written. Each suggestion must include a concrete portion amount.
        Respond with valid JSON only:
        {
          "summary": "one sentence overview of the plan",
          "tips": ["one brief tip if calories are very low or very high, otherwise empty array"],
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

    // MARK: - Codable response models

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
}
