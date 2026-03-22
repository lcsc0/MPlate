//
//  HomepageView.swift
//  MPlate
//

import SwiftUI

struct Homepage: SwiftUI.View {
    @EnvironmentObject var toggleManager: ToggleManager
    @State private var showAlert: Bool = false
    @AppStorage("anthropicApiKey") private var anthropicApiKey: String = ""
    @AppStorage("darkMode") private var darkMode: Bool = false
    @AppStorage("healthGoals") private var healthGoals: String = ""
    @State private var apiKeyInput: String = ""
    @State private var apiKeySaved = false
    @State private var healthGoalsDraft: String = ""
    @State private var healthGoalsSaved = false
    @State private var calorieGoalInput: String = ""
    @State private var calorieGoalSaved = false
    @State private var currentCalorieGoal: Int64 = 2000
    @AppStorage("goalProtein") private var goalProtein: Int = 150
    @AppStorage("goalFat") private var goalFat: Int = 65
    @AppStorage("goalCarbs") private var goalCarbs: Int = 250
    @AppStorage("goalFiber") private var goalFiber: Int = 25
    @AppStorage("goalSodium") private var goalSodium: Int = 2300
    @AppStorage("goalSugar") private var goalSugar: Int = 50
    @AppStorage("goalCalcium") private var goalCalcium: Int = 1300
    @AppStorage("goalIron") private var goalIron: Int = 18
    @AppStorage("goalVitC") private var goalVitC: Int = 90
    @AppStorage("goalVitD") private var goalVitD: Int = 20
    @AppStorage("goalPotassium") private var goalPotassium: Int = 4700
    @State private var showGoalsEditor: Bool = false

    var body: some SwiftUI.View {
        NavigationStack {
            TabView {
                Tracker()
                    .tabItem {
                        Label("Tracker", systemImage: "house")
                    }
                History()
                    .tabItem {
                        Label("History", systemImage: "calendar")
                    }
                BarcodeScanView()
                    .tabItem {
                        Label("Scan", systemImage: "barcode.viewfinder")
                    }
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer().frame(height: 20)
                        HStack {
                            Text("Maize")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.mmaize)
                            Text("Plate")
                                .font(.largeTitle)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.mBlue)
                        }.padding(.bottom, 20)

                        // Manual Calorie Goal
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "target")
                                    .foregroundStyle(Color.mmaize)
                                Text("Calorie Goal")
                                    .font(.headline)
                            }
                            Text("Current goal: \(currentCalorieGoal) kcal/day")
                                .font(.caption)
                                .foregroundStyle(Color.gray)
                            HStack {
                                TextField("Enter calories (e.g. 2200)", text: $calorieGoalInput)
                                    .textFieldStyle(.roundedBorder)
                                    .keyboardType(.numberPad)
                                Button("Set") {
                                    if let goal = Int64(calorieGoalInput.trimmingCharacters(in: .whitespaces)), goal > 0 {
                                        DatabaseManager.setCalorieGoal(goal)
                                        currentCalorieGoal = goal
                                        calorieGoalInput = ""
                                        calorieGoalSaved = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                            calorieGoalSaved = false
                                        }
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Color.mBlue)
                                .disabled(Int64(calorieGoalInput.trimmingCharacters(in: .whitespaces)) == nil)
                            }
                            if calorieGoalSaved {
                                Text("Calorie goal updated!")
                                    .font(.caption)
                                    .foregroundStyle(Color.green)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .padding(.top, 20)
                        .onAppear {
                            currentCalorieGoal = DatabaseManager.getCurrentCalorieGoal()
                        }

                        // Health Goals
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "chart.bar.fill")
                                    .foregroundStyle(Color.mBlue)
                                Text("Daily Nutrient Goals")
                                    .font(.headline)
                                Spacer()
                                Button(showGoalsEditor ? "Done" : "Edit") {
                                    showGoalsEditor.toggle()
                                }
                                .font(.caption)
                                .foregroundStyle(Color.mBlue)
                            }
                            if showGoalsEditor {
                                VStack(spacing: 6) {
                                    NutrientGoalRow(label: "Protein (g)", value: $goalProtein)
                                    NutrientGoalRow(label: "Fat (g)", value: $goalFat)
                                    NutrientGoalRow(label: "Carbs (g)", value: $goalCarbs)
                                    NutrientGoalRow(label: "Fiber (g)", value: $goalFiber)
                                    NutrientGoalRow(label: "Sodium (mg)", value: $goalSodium)
                                    NutrientGoalRow(label: "Sugar (g)", value: $goalSugar)
                                    NutrientGoalRow(label: "Calcium (mg)", value: $goalCalcium)
                                    NutrientGoalRow(label: "Iron (mg)", value: $goalIron)
                                    NutrientGoalRow(label: "Vitamin C (mg)", value: $goalVitC)
                                    NutrientGoalRow(label: "Vitamin D (mcg)", value: $goalVitD)
                                    NutrientGoalRow(label: "Potassium (mg)", value: $goalPotassium)
                                }
                            } else {
                                // summary chips
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                                    NutrientGoalChip(label: "Protein", value: goalProtein, unit: "g")
                                    NutrientGoalChip(label: "Fat", value: goalFat, unit: "g")
                                    NutrientGoalChip(label: "Carbs", value: goalCarbs, unit: "g")
                                    NutrientGoalChip(label: "Fiber", value: goalFiber, unit: "g")
                                    NutrientGoalChip(label: "Sodium", value: goalSodium, unit: "mg")
                                    NutrientGoalChip(label: "Sugar", value: goalSugar, unit: "g")
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .padding(.top, 20)

                        // Calorie Calculator
                        NavigationLink(destination: Setup()) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "flame.fill")
                                        .foregroundStyle(Color.mmaize)
                                    Text("Calorie Calculator")
                                        .font(.headline)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(Color.gray)
                                        .font(.caption)
                                }
                                Text("Calculate your TDEE and set a calorie goal based on your stats and activity level.")
                                    .font(.caption)
                                    .foregroundStyle(Color.gray)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .padding(.horizontal)
                            .padding(.top, 20)
                        }
                        .buttonStyle(.plain)

                        // Appearance
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "moon.fill")
                                    .foregroundStyle(Color.mBlue)
                                Text("Dark Mode")
                                    .font(.headline)
                                Spacer()
                                Toggle("", isOn: $darkMode)
                                    .labelsHidden()
                            }
                            Text("Forces dark mode regardless of system setting.")
                                .font(.caption)
                                .foregroundStyle(Color.gray)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .padding(.top, 20)

                        // Health Goals for AI
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "figure.run")
                                    .foregroundStyle(Color.mmaize)
                                Text("Health Goals (AI)")
                                    .font(.headline)
                            }
                            Text("Tell the AI your goals (e.g. \"gain muscle\", \"lose fat\", \"eat more fiber\"). It will personalize suggestions.")
                                .font(.caption)
                                .foregroundStyle(Color.gray)
                            TextEditor(text: $healthGoalsDraft)
                                .frame(height: 72)
                                .padding(6)
                                .background(Color(.systemBackground))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(.systemGray4), lineWidth: 1)
                                )
                                .font(.callout)
                            HStack {
                                Spacer()
                                Button("Save") {
                                    healthGoals = healthGoalsDraft
                                    healthGoalsSaved = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { healthGoalsSaved = false }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Color.mBlue)
                                .disabled(healthGoalsDraft == healthGoals)
                            }
                            if healthGoalsSaved {
                                Text("Goals saved! AI will use these next time.")
                                    .font(.caption)
                                    .foregroundStyle(Color.green)
                            } else if !healthGoals.isEmpty {
                                Text("Current: \(healthGoals)")
                                    .font(.caption)
                                    .foregroundStyle(Color.gray)
                                    .lineLimit(2)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .padding(.top, 20)
                        .onAppear { healthGoalsDraft = healthGoals }

                        // Anthropic API Key
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(Color.mmaize)
                                Text("AI Suggestions — API Key")
                                    .font(.headline)
                            }
                            Text("Required for AI meal tips and dining recommendations. Get a free key at console.anthropic.com.")
                                .font(.caption)
                                .foregroundStyle(Color.gray)
                            HStack {
                                SecureField(anthropicApiKey.isEmpty ? "sk-ant-..." : "Key saved ✓", text: $apiKeyInput)
                                    .textFieldStyle(.roundedBorder)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                Button("Save") {
                                    let trimmed = apiKeyInput.trimmingCharacters(in: .whitespaces)
                                    if !trimmed.isEmpty {
                                        anthropicApiKey = trimmed
                                        apiKeyInput = ""
                                        apiKeySaved = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                            apiKeySaved = false
                                        }
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Color.mBlue)
                                .disabled(apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                            if apiKeySaved {
                                Text("API key saved!")
                                    .font(.caption)
                                    .foregroundStyle(Color.green)
                            } else if !anthropicApiKey.isEmpty {
                                Text("Key is set. Enter a new value above to replace it.")
                                    .font(.caption)
                                    .foregroundStyle(Color.gray)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .padding(.top, 20)

                        // About & Privacy
                        NavigationLink(destination: Info()) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "info.circle")
                                        .foregroundStyle(Color.mBlue)
                                    Text("About & Privacy Policy")
                                        .font(.headline)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(Color.gray)
                                        .font(.caption)
                                }
                                Text("App info, disclaimers, and privacy policy.")
                                    .font(.caption)
                                    .foregroundStyle(Color.gray)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .padding(.horizontal)
                            .padding(.top, 20)
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }
                }
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
        .navigationBarBackButtonHidden()
        .preferredColorScheme(darkMode ? .dark : nil)
        .hideKeyboardOnTap()
    }
}

private struct NutrientGoalRow: View {
    let label: String
    @Binding var value: Int
    @State private var text: String = ""

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextField("", text: $text)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
                .multilineTextAlignment(.trailing)
                .onChange(of: text) { _, new in
                    if let v = Int(new) { value = v }
                }
        }
        .onAppear { text = "\(value)" }
    }
}

private struct NutrientGoalChip: View {
    let label: String
    let value: Int
    let unit: String
    var body: some View {
        VStack(spacing: 1) {
            Text(label).font(.caption2).foregroundStyle(Color.gray)
            Text("\(value)\(unit)").font(.caption).fontWeight(.semibold).foregroundStyle(Color.mBlue)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

#Preview {
    Homepage()
}
