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
                Text(spec.title.uppercased())
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.secondary)
                Spacer()
                Text(spec.value)
                    .font(.title3)
                    .fontWeight(.medium)
                    .monospacedDigit()
            }
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
                .frame(height: 110)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }
}
