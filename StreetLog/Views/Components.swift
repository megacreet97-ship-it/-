import SwiftUI

enum Theme {
    static let orange = Color(red: 1.0, green: 0.45, blue: 0.2)
    static let pink = Color(red: 1.0, green: 0.23, blue: 0.45)
    static let blue = Color(red: 0.32, green: 0.62, blue: 1.0)
    static let violet = Color(red: 0.64, green: 0.45, blue: 1.0)
    static let green = Color(red: 0.25, green: 0.86, blue: 0.52)
    static let yellow = Color(red: 1.0, green: 0.8, blue: 0.25)

    static let accentGradient = LinearGradient(colors: [orange, pink], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let card = Color(.secondarySystemBackground)
    static let elevated = Color(.tertiarySystemBackground)
    static let cardRadius: CGFloat = 24
}

extension Lift {
    var color: Color {
        switch self {
        case .pullUp: Theme.blue
        case .dip: Theme.violet
        }
    }
}

extension SportRank {
    var color: Color {
        switch self {
        case .kms: Theme.blue
        case .ms: Theme.orange
        case .msmk: Theme.yellow
        }
    }
}

// MARK: - Containers

struct Card<Content: View>: View {
    var title: String?
    var systemImage: String?
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title {
                HStack(spacing: 8) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.accentGradient)
                    }
                    Text(title).font(.headline)
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(padding)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06))
        )
    }
}

struct SectionTitle: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.title3.weight(.bold))
            Spacer()
            if let trailing {
                Text(trailing).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Metrics

struct StatTile: View {
    let title: String
    let value: String
    var caption: String?
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(tint)
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

struct RingProgress: View {
    let progress: Double
    var lineWidth: CGFloat = 14
    var colors: [Color] = [Theme.orange, Theme.pink]

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(min(progress, 1), 0.001))
                .stroke(
                    AngularGradient(colors: colors + [colors.first ?? Theme.orange], center: .center),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .animation(.spring(duration: 0.6), value: progress)
    }
}

struct Pill: View {
    let text: String
    var systemImage: String?
    var tint: Color = Theme.orange

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage { Image(systemName: systemImage) }
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .lineLimit(1)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .foregroundStyle(tint)
        .background(tint.opacity(0.16), in: Capsule())
    }
}

struct IconBadge: View {
    let systemImage: String
    var tint: Color = Theme.orange
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))
    }
}

struct TargetProgressRow: View {
    let title: String
    let current: Double
    let target: Double
    var tint: Color = Theme.orange

    private var fraction: Double { TargetMath.fraction(current: current, target: target) }
    private var done: Bool { target > 0 && current >= target }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.subheadline.weight(.medium))
                Spacer()
                Text(Format.kg(current)).font(.subheadline.weight(.bold)).monospacedDigit()
                Text("/ \(target > 0 ? Format.kg(target) : "—")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            ProgressBar(fraction: fraction, tint: done ? Theme.green : tint)
            if target > 0 {
                Text(done ? "Выполнено" : "Осталось \(Format.kg(target - current)) · \(Int(fraction * 100))%")
                    .font(.caption)
                    .foregroundStyle(done ? Theme.green : .secondary)
            }
        }
    }
}

struct ProgressBar: View {
    let fraction: Double
    var tint: Color = Theme.orange
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(LinearGradient(colors: [tint.opacity(0.65), tint], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(proxy.size.width * min(max(fraction, 0), 1), height))
            }
        }
        .frame(height: height)
    }
}

// MARK: - Inputs

struct BigStepper: View {
    let title: String
    @Binding var value: Double
    var step: Double = 1
    var range: ClosedRange<Double> = 0...999
    var unit: String?
    var quickSteps: [Double] = []

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(title).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                Spacer()
            }
            HStack(spacing: 16) {
                roundButton("minus") { change(by: -step) }
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(Format.number(value))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: value))
                    if let unit {
                        Text(unit).font(.headline).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                roundButton("plus") { change(by: step) }
            }
            if !quickSteps.isEmpty {
                HStack(spacing: 8) {
                    ForEach(quickSteps, id: \.self) { delta in
                        quickButton(delta > 0 ? "+\(Format.number(delta))" : "−\(Format.number(-delta))") { change(by: delta) }
                    }
                    quickButton("0") { withAnimation(.snappy) { value = range.lowerBound } }
                }
            }
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .sensoryFeedback(.selection, trigger: value)
    }

    private func change(by delta: Double) {
        withAnimation(.snappy) {
            value = min(max(value + delta, range.lowerBound), range.upperBound)
        }
    }

    private func roundButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title3.weight(.bold))
                .frame(width: 52, height: 52)
                .background(Theme.elevated, in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func quickButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Theme.elevated, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

extension Binding where Value == Int {
    var asDouble: Binding<Double> {
        Binding<Double>(get: { Double(wrappedValue) }, set: { wrappedValue = Int($0.rounded()) })
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

struct GradientButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.accentGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Theme.pink.opacity(0.35), radius: 16, y: 6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy, value: configuration.isPressed)
    }
}

struct SegmentedCapsules<Item: Hashable>: View {
    let items: [Item]
    @Binding var selection: Item
    let title: (Item) -> String

    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items, id: \.self) { item in
                Button {
                    withAnimation(.snappy) { selection = item }
                } label: {
                    Text(title(item))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(selection == item ? Color.white : Color.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background {
                            if selection == item {
                                Capsule()
                                    .fill(Theme.accentGradient)
                                    .matchedGeometryEffect(id: "selection", in: namespace)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Theme.card, in: Capsule())
    }
}

extension Date {
    var shortRu: String { formatted(.dateTime.day().month(.abbreviated).year(.twoDigits)) }
    var dayMonth: String { formatted(.dateTime.day().month(.abbreviated)) }
}
