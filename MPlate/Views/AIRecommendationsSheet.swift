//
//  AIRecommendationsSheet.swift
//  MPlate
//

import SwiftUI

struct AIRecommendationsSheet: View {
    @ObservedObject var aiService: AIService
    let diningHall: String

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if aiService.isLoading {
                        HStack {
                            Spacer()
                            VStack(spacing: 12) {
                                ProgressView()
                                Text("Analyzing menu…")
                                    .foregroundStyle(Color.gray)
                                    .font(.subheadline)
                            }
                            .padding(.top, 40)
                            Spacer()
                        }
                    } else if let err = aiService.errorMessage {
                        Text(err)
                            .foregroundStyle(Color.red)
                            .padding()
                    } else if let s = aiService.suggestion {
                        Text(s.summary)
                            .font(.subheadline)
                            .foregroundStyle(Color.secondary)
                            .padding(.horizontal)

                        if !s.recommendedItems.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(s.recommendedItems, id: \.name) { item in
                                    HStack(alignment: .top, spacing: 12) {
                                        Image(systemName: "fork.knife")
                                            .foregroundStyle(Color.mBlue)
                                            .frame(width: 20)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(item.name)
                                                .font(.system(size: 15, weight: .semibold))
                                            Text(item.reason)
                                                .font(.caption)
                                                .foregroundStyle(Color.gray)
                                        }
                                        Spacer()
                                        Text("\(item.calories) cal")
                                            .font(.caption)
                                            .foregroundStyle(Color.mBlue)
                                            .fontWeight(.semibold)
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 10)
                                    Divider().padding(.leading, 52)
                                }
                            }
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                            .padding(.horizontal)
                        }
                    } else {
                        Text("Tap the sparkle button to get recommendations.")
                            .foregroundStyle(Color.gray)
                            .padding()
                    }
                }
                .padding(.top, 8)
            }
            .navigationTitle("What should I get?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text(diningHall.replacingOccurrences(of: " Dining Hall", with: ""))
                        .font(.caption)
                        .foregroundStyle(Color.gray)
                }
            }
        }
    }
}
