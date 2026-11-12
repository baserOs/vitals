import Charts
import SwiftUI

struct ChartPoint: Identifiable {
    let date: Date
    let value: Double

    var id: Date { date }
}

/// Everything one history graph needs.
struct ChartSpec: Identifiable {
    let title: String
    /// The current value, already formatted.
    let value: String
    let points: [ChartPoint]
    /// What the value is measured against, for example "of 96 W". nil
    /// when the scale needs no explaining.
    var limit: String? = nil
    /// The vertical range. Starts at zero.
    let domain: ClosedRange<Double>
    /// The time span along the bottom.
    let window: ClosedRange<Date>
    let tint: Color

    var id: String { title }
}

/// A small line graph of one value over the last few minutes.
struct HistoryChart: View {
    let spec: ChartSpec

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(spec.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(spec.value)
                    .font(.title3)
                    .fontWeight(.medium)
                    .monospacedDigit()
                if let limit = spec.limit {
                    Text(limit)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                        .monospacedDigit()
                }
            }
            .lineLimit(1)
            if spec.points.count < 2 {
                Text("Collecting…")
                    .font(.callout)
                    .foregroundStyle(Color.secondary)
                    .frame(maxWidth: .infinity, minHeight: 110, maxHeight: 110)
            } else {
                Chart(spec.points) { point in
                    AreaMark(x: .value("Time", point.date), y: .value("Value", point.value))
                        .foregroundStyle(spec.tint.opacity(0.15))
                    LineMark(x: .value("Time", point.date), y: .value("Value", point.value))
                        .foregroundStyle(spec.tint)
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                }
                .chartYScale(domain: spec.domain)
                .chartXScale(domain: spec.window)
                .chartXAxis(.hidden)
                // Bottom, middle and top, so the top of the scale is always labelled.
                .chartYAxis {
                    AxisMarks(values: [spec.domain.lowerBound,
                                       (spec.domain.lowerBound + spec.domain.upperBound) / 2,
                                       spec.domain.upperBound]) { mark in
                        AxisGridLine()
                        AxisValueLabel {
                            if let number = mark.as(Double.self) {
                                // A scale that tops out below 10 needs its decimals.
                                Text(spec.domain.upperBound < 10 ? String(format: "%.1f", number)
                                     : "\(Int(number.rounded()))")
                            }
                        }
                    }
                }
                .frame(height: 110)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }
}
