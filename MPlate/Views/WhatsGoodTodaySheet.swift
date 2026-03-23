//
//  WhatsGoodTodaySheet.swift
//  MPlate
//

import SwiftUI

struct WhatsGoodTodaySheet: View {
    @ObservedObject var aiService: AIService
    let diningHall: String

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if aiService.isWhatsGoodLoading {
                        HStack {
                            Spacer()
                            VStack(spacing: 12) {
                                ProgressView()
                                Text("Scanning today's menu…")
                                    .foregroundStyle(Color.gray)
                                    .font(.subheadline)
                            }
                            .padding(.top, 40)
                            Spacer()
                        }
                    } else if let err = aiService.whatsGoodError {
                        Text(err)
                            .foregroundStyle(Color.red)
                            .padding()
                    } else if let result = aiService.whatsGoodResult {
                        // Summary
                        Text(result.summary)
                            .font(.subheadline)
                            .foregroundStyle(Color.secondary)
                            .padding(.horizontal)

                        if !result.items.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(result.items) { item in
                                    HStack(alignment: .top, spacing: 12) {
                                        // Score badge
                                        ZStack {
                                            Circle()
                                                .fill(scoreColor(item.score))
                                                .frame(width: 36, height: 36)
                                            Text("\(item.score)")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundStyle(Color.white)
                                        }

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(item.name)
                                                .font(.system(size: 15, weight: .semibold))
                                            HStack(spacing: 6) {
                                                Text(item.serving)
                                                    .font(.caption2)
                                                    .foregroundStyle(Color.mBlue)
                                                Text("\(item.calories) cal")
                                                    .font(.caption2)
                                                    .fontWeight(.medium)
                                                    .foregroundStyle(Color.mBlue)
                                            }
                                            HStack(spacing: 8) {
                                                Text("\(item.protein)g P")
                                                    .font(.caption2)
                                                    .foregroundStyle(Color(.systemBlue))
                                                Text("\(item.fat)g F")
                                                    .font(.caption2)
                                                    .foregroundStyle(Color.mmaize)
                                                Text("\(item.carbs)g C")
                                                    .font(.caption2)
                                                    .foregroundStyle(Color.green)
                                            }
                                            Text(item.reason)
                                                .font(.caption2)
                                                .foregroundStyle(Color.gray)
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 10)
                                    Divider().padding(.leading, 60)
                                }
                            }
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                            .padding(.horizontal)
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "star.fill")
                                .font(.largeTitle)
                                .foregroundStyle(Color.mmaize)
                            Text("See the best items on today's menu for your goals.")
                                .font(.subheadline)
                                .foregroundStyle(Color.gray)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 40)
                        .padding(.horizontal, 32)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .navigationTitle("What's Good Today?")
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

    private func scoreColor(_ score: Int) -> Color {
        if score >= 8 { return .green }
        if score >= 5 { return .mBlue }
        return .orange
    }
}
