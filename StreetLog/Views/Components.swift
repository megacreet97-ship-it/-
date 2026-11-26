import SwiftUI

struct Card<Content: View>: View {
    var title: String?
    var systemImage: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Label {
                    Text(title).font(.headline)
                } icon: {
                    if let systemImage { Image(systemName: systemImage).foregroundStyle(.tint) }
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct StatTile: View {
    let title: String
    let value: String
    var caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TargetProgressRow: View {
    let title: String
    let current: Double
    let target: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Format.kg(current)) / \(target > 0 ? Format.kg(target) : "—")")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            ProgressView(value: TargetMath.fraction(current: current, target: target))
                .tint(current >= target && target > 0 ? .green : .accentColor)
            if target > 0 {
                Text(current >= target
                     ? "Норматив выполнен"
                     : "Осталось \(Format.kg(target - current)) · \(Int(TargetMath.fraction(current: current, target: target) * 100))%")
                    .font(.caption)
                    .foregroundStyle(current >= target ? .green : .secondary)
            }
        }
    }
}

struct WeightField: View {
    let title: String
    @Binding var value: Double
    var step: Double = 1.25

    var body: some View {
        Stepper(value: $value, in: 0...500, step: step) {
            HStack {
                Text(title)
                Spacer()
                TextField("0", value: $value, format: .number.precision(.fractionLength(0...2)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 80)
                Text("кг").foregroundStyle(.secondary)
            }
        }
    }
}

extension Date {
    var shortRu: String { formatted(.dateTime.day().month(.abbreviated).year(.twoDigits)) }
}
