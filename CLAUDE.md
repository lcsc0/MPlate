# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## Project Overview

**MPlate** is an iOS SwiftUI macro-tracking app for University of Michigan students. It fetches live dining hall menus from the U-M Student Life API, lets users log meals, and uses the Claude API to generate AI-powered meal suggestions and dining hall recommendations.

## Tech Stack

- **Language:** Swift / SwiftUI
- **Min deployment:** iOS 17.5
- **Database:** SQLite via GRDB.swift (local, on-device)
- **Dependencies:** GRDB.swift, FirebaseAnalytics (managed via CocoaPods)
- **Xcode project:** `MPlate.xcodeproj` — open `MPlate.xcworkspace` after running `pod install`

## Architecture

| File | Purpose |
|------|---------|
| `MPlate/MkcalsApp.swift` | App entry point, Firebase init, database setup, routing |
| `MPlate/ContentView.swift` | Onboarding / welcome screen |
| `MPlate/Setup.swift` | Calorie goal + weight plan configuration |
| `MPlate/Homepage.swift` | 4-tab shell: Tracker, History, Info, Settings |
| `MPlate/Selector.swift` | Dining hall picker, menu display, food selection |
| `MPlate/Custom.swift` | Custom food entry with USDA nutrition search |
| `MPlate/AIService.swift` | Claude API integration (daily tips + dining recommendations) |
| `MPlate/FoodSearchService.swift` | USDA FoodData Central API search |

## Key Features

### Dining Hall Menus
- Live menus from `https://api.studentlife.umich.edu/menu/xml2print.php?...`
- 9 dining halls; bundled JSON files as offline fallback
- Selected dining hall persisted via `@AppStorage("selectedDiningHall")` — synced across Tracker and Selector tabs

### Food Logging
- Users check off menu items (with quantity picker) and tap "Add to [Meal]"
- Custom foods: search USDA FoodData Central API → auto-fills nutrition fields
- Manual entry fallback when offline or food not found

### AI Suggestions (AIService.swift)
- **Daily summary card** (Tracker tab): sends macro totals + calorie goal to Claude → returns tips
- **Dining recommendations** (Selector tab, sparkle button): sends full menu list + remaining budget → Claude recommends 3-5 specific items
- Model: `claude-haiku-4-5-20251001`
- API key stored in `UserDefaults["anthropicApiKey"]`, set via Settings tab

### Database (GRDB.swift)
Tables: `meals`, `fooditems`, `customitems3`, `user`
All data is local — no remote sync.

## Setup

```bash
cd /Users/Lucas/MPlate
pod install
open MPlate.xcworkspace
```

## API Keys

- **Anthropic (AI):** Enter in app Settings tab → stored in UserDefaults, never committed
- **USDA FoodData Central:** Hardcoded `DEMO_KEY` in `FoodSearchService.swift` — replace with a free personal key from https://fdc.nal.usda.gov/api-key-signup.html for higher rate limits
