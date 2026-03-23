//
//  MacroPieChartView.swift
//  MPlate
//

import SwiftUI

struct MacroPieChartView: View {
    let protein: Int   // grams
    let fat: Int       // grams
    let carbs: Int     // grams

    private var proteinCal: Double { Double(protein) * 4 }
    private var fatCal: Double { Double(fat) * 9 }
    private var carbsCal: Double { Double(carbs) * 4 }
    private var totalCal: Double { proteinCal + fatCal + carbsCal }

    private var slices: [(label: String, value: Double, color: Color)] {
        guard totalCal > 0 else { return [] }
        return [
            ("Protein", proteinCal, .mBlue),
            ("Fat", fatCal, .mmaize),
            ("Carbs", carbsCal, .green)
        ]
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .foregroundStyle(Color.mBlue)
                Text("Macro Breakdown")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }

            if totalCal > 0 {
                HStack(spacing: 20) {
                    // Pie chart
                    ZStack {
                        ForEach(0..<slices.count, id: \.self) { i in
                            PieSlice(
                                startAngle: sliceStart(index: i),
                                endAngle: sliceEnd(index: i)
                            )
                            .fill(slices[i].color)
                        }
                        // Center label
                        VStack(spacing: 0) {
                            Text("\(Int(totalCal))")
                                .font(.system(size: 16, weight: .bold))
                            Text("cal")
                                .font(.caption2)
                                .foregroundStyle(Color.secondary)
                        }
                    }
                    .frame(width: 100, height: 100)

                    // Legend
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(0..<slices.count, id: \.self) { i in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(slices[i].color)
                                    .frame(width: 10, height: 10)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(slices[i].label)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    let grams: Int = i == 0 ? protein : (i == 1 ? fat : carbs)
                                    let pct = Int((slices[i].value / totalCal) * 100)
                                    Text("\(grams)g (\(pct)%)")
                                        .font(.caption2)
                                        .foregroundStyle(Color.secondary)
                                }
                            }
                        }
                    }
                }
            } else {
                Text("Log food to see your macro split.")
                    .font(.caption)
                    .foregroundStyle(Color.gray)
                    .padding(.vertical, 8)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal, 18)
    }

    private func sliceStart(index: Int) -> Angle {
        let sum = slices.prefix(index).reduce(0.0) { $0 + $1.value }
        return .degrees((sum / totalCal) * 360 - 90)
    }

    private func sliceEnd(index: Int) -> Angle {
        let sum = slices.prefix(index + 1).reduce(0.0) { $0 + $1.value }
        return .degrees((sum / totalCal) * 360 - 90)
    }
}

// MARK: - Pie slice shape

private struct PieSlice: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let innerRadius = radius * 0.55  // donut style

        var path = Path()
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.addArc(center: center, radius: innerRadius, startAngle: endAngle, endAngle: startAngle, clockwise: true)
        path.closeSubpath()
        return path
    }
}
