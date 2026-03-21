# M-Cals Improvement Plan

**Date:** 2026-03-21
**Repo:** https://github.com/pattersongrant/M-Cals
**Stack:** iOS, SwiftUI, GRDB.swift (SQLite), CocoaPods

---

## Overview

Three core improvements:

1. **Auto macro lookup** — when a user adds a custom food, search a nutrition database and auto-populate calories/protein/fat/carbs instead of manual entry
2. **AI suggestions** — use Claude to analyze logged meals and provide personalized feedback, goal-tracking insights, and dining hall recommendations
3. **Persistent, switchable dining hall selection** — user can set and change their dining hall at any time; the AI-generated daily meal plan always reflects the currently selected hall's menu

---

## Feature 1: Auto Macro Lookup (Custom Food Search)

### Problem

`Custom.swift` currently requires users to manually type every nutrition value. This is friction-heavy and error-prone.

### Solution

Replace the manual entry form with a **search-first flow**:

1. User types a food name
2. App queries a nutrition API and returns a list of matching foods
3. User taps one → nutrition fields auto-fill
4. User can still edit values before saving

### Recommended API: USDA FoodData Central

- **URL:** `https://api.nal.usda.gov/fdc/v1/foods/search`
- **Why:** Free, no paid tier, government-maintained, comprehensive, returns standard nutrients (calories, protein, fat, carbs) in a clean JSON format
- **Key:** Free API key from https://fdc.nal.usda.gov/api-key-signup.html
- **Fallback:** Open Food Facts (`https://world.openfoodfacts.org/cgi/search.pl`) — fully open, no key required, but data quality is more variable

### Implementation Plan

#### New file: `FoodSearchService.swift`
```
- struct FoodSearchResult: Identifiable
    - id, name, calories, protein, fat, carbs, servingSize
- class FoodSearchService: ObservableObject
    - @Published var results: [FoodSearchResult]
    - @Published var isLoading: Bool
    - @Published var error: String?
    - func search(query: String) async
        - debounce 400ms to avoid excessive API calls
        - hits USDA endpoint, parses response
        - maps nutrient IDs: 1008=calories, 1003=protein, 1004=fat, 1005=carbs
```

#### Changes to `Custom.swift`

**Current flow:**
```
Name field → Manual calories → Manual protein → Manual fat → Manual carbs → Save
```

**New flow:**
```
Search field → API results list → Tap to select → (pre-filled, editable) fields → Save
```

- Add a `TextField` at the top: "Search for a food..."
- Wire to `FoodSearchService` with `.onChange` + debounce
- Show a `List` of results below the search bar while `isLoading == false && !results.isEmpty`
- On selection, populate the existing name/cal/protein/fat/carb `@State` vars
- Keep the manual entry path for offline/not-found cases via a "Enter manually" button
- Store the API key in a `.xcconfig` / `Info.plist` environment variable (not hardcoded)

#### UI States to Handle
- **Loading:** `ProgressView` spinner while fetching
- **No results:** "No results found. Enter manually." with fallback button
- **Error / offline:** Toast or inline error, fallback to manual
- **Rate limit:** Graceful message, fallback to manual

---

## Feature 2: AI-Powered Meal Suggestions

### Problem

The app tracks macros but gives no feedback. Users don't know if they're on track, what to prioritize at their next meal, or how their current week compares to their goals.

### Solution

Add a **Claude-powered AI tab or panel** that reads the user's logged meals + goal settings and returns actionable insights.

### Recommended Model

`claude-haiku-4-5-20251001` — fast and cheap, appropriate for structured short-form suggestions on a mobile client.

### Two Surfaces

#### Surface A: Daily Summary Card (Homepage.swift)

After meals are logged, show an AI summary card at the bottom of the Tracker tab:

- "You've hit 82% of your protein goal. Add a protein-heavy snack at dinner."
- "You're 400 calories under your goal with one meal left — consider [dining hall item] or a balanced snack."
- Tap to expand for a full breakdown

**Trigger:** Generate (or refresh) when the user taps a "Get Suggestions" button, or automatically when they return to the Tracker tab after logging food.

#### Surface B: Dining Hall Recommendation (Selector.swift)

Before or after menu load, add a "What should I get?" button. Claude receives:
- The full menu item list for the selected dining hall + meal
- The user's remaining macro budget for the day
- The user's weight goal (gain/maintain/lose)

And returns:
- A ranked list of 3–5 recommended items with a one-line reason each
- Estimated macro contribution if user selects them

### Implementation Plan

#### New file: `AIService.swift`
```
- struct MealSuggestion: Codable
    - summary: String
    - tips: [String]
    - recommendedItems: [RecommendedItem]?  // only for dining hall surface

- struct RecommendedItem: Codable
    - name: String
    - reason: String
    - estimatedCalories: Int

- class AIService: ObservableObject
    - func getDailySummary(loggedMeals: [Meal], goal: UserGoal) async -> MealSuggestion
    - func getDiningRecommendations(menuItems: [MenuItem], remainingMacros: MacroBudget) async -> MealSuggestion
    - private func callClaude(systemPrompt: String, userMessage: String) async throws -> String
```

The Claude call structure:
```json
{
  "model": "claude-haiku-4-5-20251001",
  "max_tokens": 512,
  "system": "<role + output format instructions>",
  "messages": [{ "role": "user", "content": "<meal data + goals as JSON>" }]
}
```

Expect structured JSON back (same pattern as the existing `diningplanner.jsx`).

#### API Key Storage

- Store Anthropic API key in `.xcconfig` → `Info.plist` → read at runtime via `Bundle.main.infoDictionary`
- Never commit the key to git; add `.xcconfig` to `.gitignore`
- Add a Settings screen field to let users paste their own key (power users / dev)

#### Changes to `Homepage.swift`

- Add `@StateObject var aiService = AIService()`
- Add an `AISummaryCard` SwiftUI component below the macro progress bars
- "Get Suggestions" button triggers `getDailySummary`
- Show loading state, then render tips as a bulleted list

#### Changes to `Selector.swift`

- Add "What should I get?" button in the dining hall picker header
- Calls `getDiningRecommendations` with current menu + user's remaining macros for the day
- Presents result in a sheet/modal ranked list

---

## Feature 3: Persistent, Switchable Dining Hall Selection

### Problem

Currently the dining hall picker in `Selector.swift` is ephemeral — it resets when the user navigates away. The AI daily meal plan has no concept of "where is this user eating today?", so it can't ground its suggestions in real, available menu items.

### Solution

- Persist the selected dining hall (and meal period) so it survives tab switches and app restarts
- Surface the picker prominently on the Tracker tab (not just inside Selector) so the user can change it at any time without navigating away
- Feed the persisted selection into the AI daily meal plan so suggestions are always grounded in what's actually available

### State & Persistence

Store the selected dining hall in `UserDefaults` (lightweight, appropriate for a single string preference):

```
UserDefaults.standard.set(selectedHall, forKey: "selectedDiningHall")
UserDefaults.standard.set(selectedMeal, forKey: "selectedMealPeriod")
```

Read on app launch via `@AppStorage` in SwiftUI:

```swift
@AppStorage("selectedDiningHall") var selectedDiningHall: String = "South Quad"
@AppStorage("selectedMealPeriod") var selectedMealPeriod: String = "Lunch"
```

This means the selection is available app-wide without passing it through view hierarchies.

### UI Changes

#### Tracker Tab (`Homepage.swift`)

Add a compact "Eating at:" banner near the top of the Tracker tab:

```
┌─────────────────────────────────────────┐
│  Eating at:  South Quad · Lunch   [Change] │
└─────────────────────────────────────────┘
```

- Tapping **[Change]** presents a sheet with the hall + meal period pickers
- Selection saves immediately via `@AppStorage`
- The `AISummaryCard` (Feature 2) reads this selection and fetches the current menu for that hall before calling Claude — so AI tips reference real available items

#### Selector Tab (`Selector.swift`)

- Pre-populate the hall/meal pickers from `@AppStorage` on view appear
- Any change the user makes in Selector also writes back to `@AppStorage`, keeping both surfaces in sync
- No more reset-on-navigate

### Impact on AI Meal Plan

The `getDailySummary` function in `AIService.swift` gains a new parameter:

```swift
func getDailySummary(
    loggedMeals: [Meal],
    goal: UserGoal,
    availableMenuItems: [MenuItem]   // <-- new: from selected hall + meal period
) async -> MealSuggestion
```

Claude's system prompt is updated to instruct it to **only recommend items that appear in `availableMenuItems`** when giving suggestions for upcoming meals. This makes the daily summary card actionable — "You need more protein; grab the Grilled Chicken at South Quad" — rather than generic.

### Edge Cases

| Scenario | Behavior |
|----------|----------|
| No hall selected yet | Prompt user to pick one; disable AI suggestions until set |
| Selected hall API unavailable | Fall back to bundled JSON for that hall; note in UI |
| User changes hall mid-day | Re-fetch menu and regenerate suggestions; log already-eaten meals are unaffected |
| Selected meal period has ended | Show a warning; still allow viewing menu and generating a plan |

---

## Implementation Order

| Step | Task | Files Touched |
|------|------|---------------|
| 1 | Add USDA FoodData Central API key to `.xcconfig` | `.xcconfig`, `.gitignore`, `Info.plist` |
| 2 | Build `FoodSearchService.swift` with search + response parsing | new file |
| 3 | Refactor `Custom.swift` to search-first UI | `Custom.swift` |
| 4 | Add `@AppStorage` for dining hall + meal period; add "Eating at:" banner to Tracker tab | `Homepage.swift` |
| 5 | Sync `Selector.swift` pickers to `@AppStorage` (pre-populate + write-back on change) | `Selector.swift` |
| 6 | Add Anthropic API key to config | `.xcconfig`, `Info.plist` |
| 7 | Build `AIService.swift` with Claude integration; include `availableMenuItems` param | new file |
| 8 | Add `AISummaryCard` to Tracker tab wired to selected hall's live menu | `Homepage.swift` |
| 9 | Add "What should I get?" recommendation sheet to Selector | `Selector.swift` |
| 10 | Add API key settings field | `Homepage.swift` Settings tab or new `Settings.swift` |

---

## Data Privacy Notes

- USDA queries are stateless (no account linkage)
- Claude API calls should **not** include the user's name or any PII — only anonymous nutrition numbers and goal type
- Both keys stay on-device; no new backend required
- Consistent with the app's existing privacy-first approach

---

## Out of Scope (For Now)

- Barcode scanner (would be a strong future addition alongside food search)
- Meal planning across multiple days
- Syncing to Apple Health
- Android port
