//
//  AIService.swift
//  M-Cals
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
    }
}

// MARK: - Input model (menu item passed in from Selector)

struct AIMenuItem {
    let name: String
    let kcal: Int
    let protein: Int
    let fat: Int
    let carbs: Int
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

    // MARK: Daily summary (Tracker tab)

    func getDailySummary(
        totalCalories: Int,
        totalProtein: Int,
        totalFat: Int,
        totalCarbs: Int,
        calorieGoal: Int
    ) async {
        guard !apiKey.isEmpty else {
            errorMessage = "Add your Anthropic API key in Settings to enable AI suggestions."
            return
        }

        isLoading = true
        errorMessage = nil
        suggestion = nil

        let pct = calorieGoal > 0 ? Int(Double(totalCalories) / Double(calorieGoal) * 100) : 0
        let remaining = max(0, calorieGoal - totalCalories)

        let userMessage = """
        Today's nutrition so far:
        - Calories: \(totalCalories) / \(calorieGoal) goal (\(pct)% complete, \(remaining) remaining)
        - Protein: \(totalProtein)g
        - Fat: \(totalFat)g
        - Carbs: \(totalCarbs)g

        Give practical meal tips for the rest of the day to hit the calorie goal with balanced macros.
        """

        let systemPrompt = """
        You are a concise nutrition assistant for a University of Michigan student tracking macros at dining halls.
        Give 2-3 short, actionable tips based on their current intake vs goal.
        Respond with valid JSON only: {"summary": "one sentence", "tips": ["tip1", "tip2", "tip3"]}
        Keep each tip under 15 words. No markdown in JSON values.
        """

        do {
            let raw = try await callClaude(system: systemPrompt, user: userMessage)
            let cleaned = extractJSON(from: raw)
            if let data = cleaned.data(using: .utf8),
               let json = try? JSONDecoder().decode(SummaryResponse.self, from: data) {
                suggestion = MealSuggestion(summary: json.summary, tips: json.tips, recommendedItems: [])
            } else {
                suggestion = MealSuggestion(summary: raw, tips: [], recommendedItems: [])
            }
        } catch {
            errorMessage = "AI error: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: Dining recommendations (Selector tab)

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

        let menuList = menuItems.prefix(50).map {
            "\($0.name) | \($0.kcal) cal | \($0.protein)g pro | \($0.fat)g fat | \($0.carbs)g carbs"
        }.joined(separator: "\n")

        let userMessage = """
        Remaining calories for today: \(remainingCalories)
        Remaining protein needed: \(remainingProtein)g
        Weight goal: \(weightGoal)

        Available menu items (name | calories | protein | fat | carbs):
        \(menuList)

        Recommend the best 3-5 items from this specific menu that fit my remaining budget.
        """

        let systemPrompt = """
        You are a nutrition assistant for a University of Michigan dining hall app.
        Recommend specific items from the EXACT menu list provided. Do not invent items.
        Use the item names EXACTLY as written in the list.
        Respond with valid JSON only:
        {"summary": "brief one-sentence plan", "tips": [], "recommendedItems": [{"name": "exact item name", "reason": "under 12 words", "calories": 000}]}
        No markdown in JSON values.
        """

        do {
            let raw = try await callClaude(system: systemPrompt, user: userMessage)
            let cleaned = extractJSON(from: raw)
            if let data = cleaned.data(using: .utf8),
               let json = try? JSONDecoder().decode(RecommendationResponse.self, from: data) {
                let items = json.recommendedItems.map {
                    MealSuggestion.RecommendedItem(name: $0.name, reason: $0.reason, calories: $0.calories)
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

    private func callClaude(system: String, user: String) async throws -> String {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 600,
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
            throw NSError(domain: "AIService", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "API error \(http.statusCode): \(body)"])
        }

        struct ClaudeResponse: Codable {
            struct Content: Codable { let text: String }
            let content: [Content]
        }
        let decoded = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        return decoded.content.first?.text ?? ""
    }

    /// Strips markdown code fences if Claude wraps JSON in ```json ... ```
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

    private struct SummaryResponse: Codable {
        let summary: String
        let tips: [String]
    }

    private struct RecommendationResponse: Codable {
        let summary: String
        let tips: [String]
        let recommendedItems: [Item]
        struct Item: Codable {
            let name: String
            let reason: String
            let calories: Int
        }
    }
}
