import Charts
import SwiftData
import SwiftUI

extension Goal {
    var color: Color {
        switch self {
        case .ms: Theme.orange
        case .recomp: Theme.violet
        case .fatLoss: Theme.green
        case .muscle: Theme.blue
        }
    }
}

extension GoalVerdict.Tone {
    var color: Color {
        switch self {
        case .good: Theme.green
        case .warn: Theme.orange
        case .neutral: Theme.blue
        }
    }
}

struct GoalView: View {
    let goal: Goal?
    var openExercises: () -> Void

    var body: some View {
        switch goal {
        case .ms:
            MasterView()
        case nil:
            GoalChooserView()
        case let goal?:
            FormView(goal: goal, openExercises: openExercises)
        }
    }
}

struct GoalChooserView: View {
    @Query private var profiles: [AthleteProfile]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Выберите, к чему идёте, — от этого зависит, что приложение покажет на этой вкладке. Цель можно поменять в любой момент.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    GoalPickerList(selected: nil) { profiles.first?.goal = $0 }
                }
                .padding()
            }
            .background(Color(.systemBackground))
            .navigationTitle("Цель")
        }
    }
}

struct GoalPickerList: View {
    let selected: Goal?
    var onPick: (Goal) -> Void

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Goal.allCases) { goal in
                Button {
                    withAnimation(.snappy) { onPick(goal) }
                } label: {
                    HStack(spacing: 14) {
                        IconBadge(systemImage: goal.symbol, tint: goal.color, size: 44)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(goal.title).font(.headline)
                            Text(goal.subtitle).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                        if selected == goal {
                            Image(systemName: "checkmark").font(.headline).foregroundStyle(goal.color)
                        }
                    }
                    .padding(16)
                    .background(selected == goal ? goal.color.opacity(0.12) : Theme.card,
                                in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(selected == goal ? goal.color.opacity(0.6) : Color.white.opacity(0.06)))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct GoalSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var profile: AthleteProfile
    let hasStreetliftingData: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    GoalPickerList(selected: profile.effectiveGoal(hasStreetliftingData: hasStreetliftingData)) { profile.goal = $0 }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                if let goal = profile.effectiveGoal(hasStreetliftingData: hasStreetliftingData), goal != .ms {
                    GoalTargetsSection(profile: profile)
                } else {
                    Section { Text("Федерацию, весовую и разряд для МС настройте в профиле.").font(.footnote).foregroundStyle(.secondary) }
                }
            }
            .navigationTitle("Цель")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() } }
            }
        }
    }
}

struct GoalTargetsSection: View {
    @Bindable var profile: AthleteProfile

    var body: some View {
        Section {
            OptionalNumberRow(title: "Целевой вес", unit: "кг", value: $profile.targetWeight)
            OptionalNumberRow(title: "Целевая талия", unit: "см", value: $profile.targetWaist)
            Picker("Тренировок в неделю", selection: $profile.weeklyWorkouts) {
                ForEach(2...6, id: \.self) { Text("\($0)").tag($0) }
            }
        } header: {
            Text("Целевые показатели")
        } footer: {
            Text("Можно оставить пустым. Цель по весу показывает путь и примерную дату, талия — главный показатель для рекомпозиции.")
        }
    }
}

/// Number row where 0 means "not set" and is shown as an empty field.
struct OptionalNumberRow: View {
    let title: String
    let unit: String
    @Binding var value: Double

    private var optional: Binding<Double?> {
        Binding(get: { value > 0 ? value : nil }, set: { value = max($0 ?? 0, 0) })
    }

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 6) {
                TextField("не задано", value: optional, format: .number.precision(.fractionLength(0...1)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 110)
                Text(unit).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Body composition goals

struct FormView: View {
    let goal: Goal
    var openExercises: () -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: \BodyMeasurement.date) private var measurements: [BodyMeasurement]
    @Query(sort: \WorkoutEntry.date) private var entries: [WorkoutEntry]
    @Query private var profiles: [AthleteProfile]
    @Query private var exercises: [Exercise]

    @State private var editing: MeasurementDraft?
    @State private var showingSettings = false
    @State private var chartKind = ChartKind.weight

    enum ChartKind: String, CaseIterable { case weight = "Вес", waist = "Талия" }

    private let calendar = Calendar.current
    private var profile: AthleteProfile? { profiles.first }

    private var weights: [DatedValue] { measurements.map { DatedValue(date: $0.date, value: $0.weight) } }
    private var waists: [DatedValue] { measurements.filter { $0.waist > 0 }.map { DatedValue(date: $0.date, value: $0.waist) } }
    private var weight: Double? { BodyMath.smoothedLatest(weights) }
    private var waist: Double? { BodyMath.smoothedLatest(waists) }
    private var weightRate: Double? { BodyMath.weeklyRate(weights) }
    private var waistRate: Double? { BodyMath.weeklyRate(waists, days: 42) }
    private var currentWeight: Double { weight ?? profile?.bodyweight ?? 0 }
    private var weekly: Int { profile?.weeklyWorkouts ?? 3 }

    private var workoutsThisWeek: Int {
        let start = DiaryAnalytics.weekStart(for: .now, calendar: calendar)
        return Set(entries.filter { $0.date >= start }.map { calendar.startOfDay(for: $0.date) }).count
    }

    private var lookup: (String) -> ExerciseInfo? {
        let byName = Dictionary(exercises.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        return { name in ExerciseInfo.lookup(name, category: byName[name]?.category, lift: byName[name]?.lift) }
    }

    private var weekSets: [Muscle: Double] {
        let from = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: .now)) ?? .now
        return MuscleAnalytics.sets(entries.filter { $0.date >= from }.map(\.logItem), lookup: lookup)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    heroCard
                    metricsRow
                    if let profile, profile.targetWeight > 0, let start = weights.first?.value {
                        targetCard(start: start, target: profile.targetWeight)
                    }
                    chartCard
                    measurementsCard
                    musclesCard
                    planCard
                }
                .padding()
            }
            .scrollIndicators(.hidden)
            .background(Color(.systemBackground))
            .navigationTitle("Моя форма")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { editing = MeasurementDraft(measurement: nil) } label: {
                        Label("Замер", systemImage: "plus").font(.subheadline.weight(.semibold))
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingSettings = true } label: { Image(systemName: "target") }
                        .accessibilityLabel("Настроить цель")
                }
            }
            .sheet(item: $editing) { draft in
                MeasurementSheet(measurement: draft.measurement, defaultWeight: currentWeight)
            }
            .sheet(isPresented: $showingSettings) {
                if let profile { GoalSettingsSheet(profile: profile, hasStreetliftingData: false) }
            }
        }
    }

    private var heroCard: some View {
        let verdict = BodyMath.verdict(goal: goal, weight: weight, weightPerWeek: weightRate, waistPerWeek: waistRate)
        return VStack(alignment: .leading, spacing: 16) {
            Button { showingSettings = true } label: {
                Pill(text: "Цель: \(goal.title)", systemImage: goal.symbol, tint: goal.color)
            }
            .buttonStyle(.plain)
            HStack(spacing: 18) {
                ZStack {
                    RingProgress(progress: Double(workoutsThisWeek) / Double(max(weekly, 1)))
                    VStack(spacing: 0) {
                        Text("\(workoutsThisWeek)/\(weekly)").font(.title.weight(.bold)).monospacedDigit()
                        Text("трен. за неделю").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 116, height: 116)
                VStack(alignment: .leading, spacing: 6) {
                    Text(verdict.title).font(.title3.weight(.bold)).foregroundStyle(verdict.tone.color)
                    Text(verdict.text).font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(LinearGradient(colors: [goal.color.opacity(0.22), Theme.card], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }

    private func signed(_ value: Double, _ unit: String) -> String {
        let rounded = (value * 10).rounded() / 10
        return (rounded > 0 ? "+" : rounded < 0 ? "−" : "") + Format.number(abs(rounded)) + " \(unit)/нед"
    }

    private var metricsRow: some View {
        let records = MuscleAnalytics.personalRecords(entries.map(\.logItem),
                                                      since: calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: .now)) ?? .now)
        return HStack(spacing: 10) {
            Card {
                StatTile(title: "Вес", value: weight.map { Format.number(($0 * 10).rounded() / 10) } ?? "—",
                         caption: weightRate.map { signed($0, "кг") } ?? "кг", tint: Theme.blue)
            }
            Card {
                StatTile(title: "Талия", value: waist.map { Format.number(($0 * 10).rounded() / 10) } ?? "—",
                         caption: waistRate.map { signed($0, "см") } ?? "см", tint: Theme.pink)
            }
            Card {
                StatTile(title: "Рекорды", value: "\(records)", caption: "за 30 дней", tint: Theme.yellow)
            }
        }
    }

    private func targetCard(start: Double, target: Double) -> some View {
        let left = abs(target - currentWeight)
        let eta = BodyMath.reachDate(current: currentWeight, target: target, perWeek: weightRate)
        return Card(title: "Путь к цели", systemImage: "flag.fill") {
            HStack {
                Text("Старт \(Format.kg(start))").font(.subheadline)
                Spacer()
                Text("Цель \(Format.kg(target))").font(.subheadline.weight(.bold))
            }
            ProgressBar(fraction: BodyMath.targetProgress(start: start, current: currentWeight, target: target), tint: goal.color, height: 10)
            Text(left < 0.3 ? "Цель по весу достигнута — теперь держите вес и прибавляйте в силе."
                 : "Осталось \(Format.kg((left * 10).rounded() / 10))" + (eta.map { " · при текущем темпе ~\($0.shortRu)" } ?? ""))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var chartCard: some View {
        let points = chartKind == .weight ? weights : waists
        let target = chartKind == .weight ? (profile?.targetWeight ?? 0) : (profile?.targetWaist ?? 0)
        let tint = chartKind == .weight ? Theme.blue : Theme.pink
        let trend = BodyMath.recentTrend(points, days: chartKind == .weight ? 28 : 42)
        return Card(title: "Динамика", systemImage: "chart.xyaxis.line") {
            if !waists.isEmpty {
                SegmentedCapsules(items: ChartKind.allCases, selection: $chartKind) { $0.rawValue }
            }
            if points.isEmpty {
                Text("Добавьте первый замер кнопкой «Замер» — здесь появится график.")
                    .font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 100)
            } else {
                BodyChart(points: Array(points.suffix(60)), target: target, trend: trend, tint: tint)
                    .frame(height: 190)
            }
            Text("Вес скачет на 1–2 кг из-за воды и еды, поэтому оценка идёт по тренду за 4 недели, а не по одному взвешиванию.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var measurementsCard: some View {
        Card(title: "Замеры", systemImage: "ruler") {
            if measurements.isEmpty {
                Text("Пока пусто").foregroundStyle(.secondary)
            } else {
                ForEach(Array(measurements.reversed().prefix(8))) { measurement in
                    Button { editing = MeasurementDraft(measurement: measurement) } label: {
                        HStack {
                            Text(measurement.date.shortRu).font(.subheadline)
                            Spacer()
                            if measurement.waist > 0 { Text("талия \(Format.number(measurement.waist))").font(.caption).foregroundStyle(.secondary) }
                            if measurement.bodyFat > 0 { Text("жир \(Format.number(measurement.bodyFat))%").font(.caption).foregroundStyle(.secondary) }
                            Text(Format.kg(measurement.weight)).font(.subheadline.weight(.bold)).monospacedDigit()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var musclesCard: some View {
        let sets = weekSets
        let weak = Muscle.key.filter { (sets[$0] ?? 0) < 4 }.prefix(4)
        let growing = Muscle.key.filter { (sets[$0] ?? 0) >= 10 }.count
        return Card(title: "Мышцы за 7 дней", systemImage: "figure.strengthtraining.traditional") {
            Text(growing > 0 ? "В зоне роста (10+ подходов): \(growing) из \(Muscle.key.count) основных мышц."
                 : "Пока ни одна мышца не получила 10+ подходов за неделю.")
                .font(.subheadline)
            ForEach(Array(weak)) { muscle in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Pill(text: "\(Format.number(((sets[muscle] ?? 0) * 10).rounded() / 10)) подх.", tint: Theme.orange)
                    Text(muscle.title).font(.footnote.weight(.semibold))
                        + Text(MuscleAnalytics.best(for: muscle, limit: 1).first.map { " — попробуйте «\($0.name)»" } ?? "")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            Button(action: openExercises) {
                Label("Нагрузка на все мышцы и лучшие упражнения", systemImage: "chevron.right")
                    .font(.subheadline.weight(.semibold))
            }
        }
    }

    private var planCard: some View {
        Card(title: "План: \(goal.title.lowercased())", systemImage: "list.bullet") {
            ForEach(BodyMath.plan(goal: goal, weight: currentWeight, workouts: weekly)) { tip in
                VStack(alignment: .leading, spacing: 2) {
                    Text(tip.title).font(.subheadline.weight(.bold)).foregroundStyle(goal.color)
                    Text(tip.text).font(.footnote).foregroundStyle(.secondary)
                }
            }
            Text("Общие рекомендации для здоровых взрослых. При болезнях, беременности или сильном лишнем весе цели лучше обсудить с врачом.")
                .font(.caption).foregroundStyle(.tertiary)
        }
    }
}

struct BodyChart: View {
    let points: [DatedValue]
    let target: Double
    let trend: LinearTrend?
    let tint: Color

    private var domain: ClosedRange<Double> {
        var values = points.map(\.value)
        if target > 0 { values.append(target) }
        let low = (values.min() ?? 0) - 1
        let high = (values.max() ?? 1) + 1
        return low...high
    }

    var body: some View {
        Chart {
            ForEach(points) { point in
                LineMark(x: .value("Дата", point.date), y: .value("Значение", point.value), series: .value("Ряд", "Замеры"))
                    .foregroundStyle(tint)
                    .interpolationMethod(.monotone)
                PointMark(x: .value("Дата", point.date), y: .value("Значение", point.value))
                    .foregroundStyle(tint)
                    .symbolSize(24)
            }
            if let trend, let first = points.first?.date, let last = points.last?.date {
                ForEach([first, last], id: \.self) { date in
                    LineMark(x: .value("Дата", date), y: .value("Значение", trend.value(at: date)), series: .value("Ряд", "Тренд"))
                        .foregroundStyle(Color.white.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                }
            }
            if target > 0 {
                RuleMark(y: .value("Цель", target))
                    .foregroundStyle(Theme.green)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("цель \(Format.number(target))").font(.caption2.weight(.bold)).foregroundStyle(Theme.green)
                    }
            }
        }
        .chartYScale(domain: domain)
    }
}

struct MeasurementDraft: Identifiable {
    let id = UUID()
    let measurement: BodyMeasurement?
}

struct MeasurementSheet: View {
    let measurement: BodyMeasurement?
    let defaultWeight: Double

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var profiles: [AthleteProfile]
    @Query(sort: \BodyMeasurement.date) private var measurements: [BodyMeasurement]

    @State private var weight = 60.0
    @State private var waist = 0.0
    @State private var bodyFat = 0.0
    @State private var date = Date.now
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    BigStepper(title: "Вес тела", value: $weight, step: 0.1, range: 30...250, unit: "кг", quickSteps: [-1, -0.5, 0.5, 1])
                    Text("Нажмите на число, чтобы вписать вес. Взвешивайтесь утром натощак.")
                        .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    VStack(spacing: 0) {
                        OptionalNumberRow(title: "Талия", unit: "см", value: $waist).padding(14)
                        Divider()
                        OptionalNumberRow(title: "Процент жира", unit: "%", value: $bodyFat).padding(14)
                        Divider()
                        DatePicker("Дата", selection: $date, displayedComponents: .date).padding(14)
                    }
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    Text("Талию мерьте по пупку, на выдохе, раз в неделю. Для рекомпозиции это главный показатель.")
                        .font(.caption).foregroundStyle(.secondary)
                    if let measurement {
                        Button("Удалить замер", role: .destructive) {
                            context.delete(measurement)
                            syncBodyweight(excluding: measurement)
                            dismiss()
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(measurement == nil ? "Новый замер" : "Замер")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Сохранить", action: save).fontWeight(.semibold) }
            }
            .onAppear(perform: load)
        }
        .presentationDetents([.large])
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let measurement {
            weight = measurement.weight
            waist = measurement.waist
            bodyFat = measurement.bodyFat
            date = measurement.date
        } else {
            weight = defaultWeight > 0 ? (defaultWeight * 10).rounded() / 10 : 60
        }
    }

    private func save() {
        if let measurement {
            measurement.weight = weight
            measurement.waist = waist
            measurement.bodyFat = bodyFat
            measurement.date = date
        } else {
            context.insert(BodyMeasurement(date: date, weight: weight, waist: waist, bodyFat: bodyFat))
        }
        syncBodyweight(excluding: nil)
        dismiss()
    }

    /// Keeps the profile weight equal to the latest measurement, which the 1RM estimates also use.
    private func syncBodyweight(excluding removed: BodyMeasurement?) {
        var all = measurements.filter { $0 !== removed }.map { ($0.date, $0.weight) }
        if measurement == nil && removed == nil { all.append((date, weight)) }
        if let latest = all.max(by: { $0.0 < $1.0 }) { profiles.first?.bodyweight = latest.1 }
    }
}
