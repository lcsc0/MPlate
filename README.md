# MaizePlate

A calorie and macro tracking iOS app built for University of Michigan students. MaizePlate pulls live dining hall menus from the U-M Student Life API, lets you log meals with a tap, and uses AI to recommend exactly what to eat next based on your remaining budget.

> **Not an official U-M application.** Not affiliated with the University of Michigan.

---

## Features

### Dining Hall Menus
- Live menus from all 9 U-M dining halls, fetched once per day and cached — no redundant network calls
- Offline fallback to bundled JSON menus
- Breakfast, Lunch, Dinner tabs + an **Other** tab (condiments, beverages, salad bar, deli, desserts, etc.) with full nutrition info

### Meal Logging
- Tap items to select them, set quantities, and add to any meal
- Custom food entry with USDA FoodData Central search
- **Barcode scanner** — scan any packaged food and auto-fill nutrition from Open Food Facts

### Nutrition Tracking
Tracks all of the following, pulled directly from U-M dining data:
- Calories, Protein, Fat, Carbohydrates
- Fiber, Sodium, Sugar, Saturated Fat, Cholesterol
- Calcium, Iron, Vitamin C, Vitamin D, Potassium

### Daily Report
Tap **Generate Report** on the Tracker to see a full nutrition label for the day, including % Daily Value for every nutrient scaled to your personal calorie goal.

### AI Suggestions (Powered by Claude)
- **Tracker tab**: tap "Get Tips" to receive specific meal recommendations with portion sizes, pulled from today's actual dining hall menu
- **Selector tab**: tap the sparkle button to get AI-curated picks from the current menu matching your remaining calorie and protein budget
- Requires a personal Anthropic API key (add in Settings)

### Health Goals
Set custom daily targets for every tracked nutrient in Settings → Daily Nutrient Goals. Automatically reflected in the report.

### History
Browse past days with a calendar date picker. Calorie trend chart (7 days, 1 month, 3 months). Fully scrollable.

### Calorie Calculator
TDEE calculator built in — enter your stats and activity level to get a science-based calorie goal, or set it manually in Settings.

---

## Tech Stack

| | |
|---|---|
| **Language** | Swift / SwiftUI |
| **Min deployment** | iOS 17.5 |
| **Database** | SQLite via GRDB.swift (local, on-device) |
| **Dependencies** | GRDB.swift, FirebaseAnalytics (CocoaPods) |
| **AI** | Anthropic Claude API (`claude-haiku-4-5`) |
| **Barcode nutrition** | Open Food Facts API (no key required) |
| **Food search** | USDA FoodData Central API |
| **Menu data** | U-M Student Life API + bundled JSON fallback |

---

## Setup

```bash
git clone https://github.com/lcsc0/MPlate.git
cd MPlate
pod install
open MPlate.xcworkspace
```

Build and run on a device or simulator running iOS 17.5+.

### API Keys

| Service | How to get it | Where to set it |
|---|---|---|
| **Anthropic (AI suggestions)** | [console.anthropic.com](https://console.anthropic.com) | App → Settings → AI Suggestions |
| **USDA FoodData Central** | [fdc.nal.usda.gov/api-key-signup](https://fdc.nal.usda.gov/api-key-signup.html) | `FoodSearchService.swift` (replace `DEMO_KEY`) |

The Anthropic key is stored in `UserDefaults` on-device and never committed to the repo.

---

## Architecture

```
MPlate/
├── App/
│   └── MPlateApp.swift          # Entry point, Firebase init, DB setup
├── Models/
│   ├── MenuModels.swift          # Menu → Meal → Course → MenuItem → Nutrition
│   ├── FoodItem.swift            # Logged food item + nutrient calculation
│   ├── TDEEModels.swift          # Activity level / TDEE calculation models
│   └── TrendModels.swift         # Calorie trend chart data
├── Services/
│   ├── MenuService.swift         # U-M API fetch + daily in-memory cache
│   ├── DatabaseManager.swift     # GRDB SQLite reads/writes + migration
│   ├── AIService.swift           # Anthropic Claude API integration
│   └── FoodSearchService.swift   # USDA FoodData Central search
├── Utilities/
│   ├── ToggleManager.swift       # App-wide observable state
│   └── ViewExtensions.swift      # hideKeyboardOnTap modifier
└── Views/
    ├── ContentView.swift          # Onboarding / welcome screen
    ├── HomepageView.swift         # 4-tab shell: Tracker, History, Scan, Settings
    ├── TrackerView.swift          # Daily meal log + AI suggestions
    ├── HistoryView.swift          # Past days + calorie trend chart
    ├── SelectorView.swift         # Dining hall menu picker + food selection
    ├── CustomFoodView.swift       # Manual food entry + USDA search
    ├── BarcodeScanView.swift      # Camera barcode scanner
    ├── DailyReportView.swift      # Full-day nutrition report with % DV
    ├── SetupView.swift            # TDEE calculator + calorie goal setup
    ├── AIRecommendationsSheet.swift
    ├── NutritionViewer.swift
    └── InfoView.swift
```

---

## Data & Privacy

All logged food data is stored locally on-device in SQLite. Deleting the app erases all data. No food or health data is ever sent to any server.

Approximate location and anonymous usage analytics are collected via Firebase for development purposes only and are never shared with third parties.
