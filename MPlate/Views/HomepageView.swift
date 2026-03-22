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
    @State private var apiKeyInput: String = ""
    @State private var apiKeySaved = false

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
                Info()
                    .tabItem {
                        Label("Info", systemImage: "info.circle")
                    }
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer().frame(height: 20)
                        HStack {
                            Text("M")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.mmaize)
                            Text("Cals")
                                .font(.largeTitle)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.mBlue)
                        }.padding(.bottom, 20)

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
    }
}

#Preview {
    Homepage()
}
