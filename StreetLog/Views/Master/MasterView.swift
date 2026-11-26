import Charts
import SwiftData
import SwiftUI

struct MasterView: View {
    @Query(sort: \MaxAttempt.date) private var attempts: [MaxAttempt]
    @Query(sort: \WorkoutEntry.date) private var entries: [WorkoutEntry]
    @Query private var profiles: [AthleteProfile]

    @State private var chartLift: Lift = .pullUp
    @State private var showingNewAttempt = false

    private let calendar = Calendar.current

    private var profile: AthleteProfile? { profiles.first }
    private var bodyweight: Double { profile?.bodyweight ?? 0 }
    private var competition: Date? { profile?.competitionDate }

    private func best(_ lift: Lift) -> Double {
        attempts.filter { $0.lift == lift }.map(\.addedWeight).max() ?? 0
    }

    private func attemptPoints(_ lift: Lift) -> [DatedValue] {
        dailyMax(attempts.filter { $0.lift == lift }.map { DatedValue(date: $0.date, value: $0.addedWeight) })
    }

    private func estimatePoints(_ lift: Lift) -> [DatedValue] {
        dailyMax(entries.compactMap { entry -> DatedValue? in
            guard entry.lift == lift, entry.reps > 1,
                  let estimate = OneRepMax.estimatedAddedWeight(added: entry.addedWeight, bodyweight: bodyweight, reps: entry.reps)
            else { return nil }
            return DatedValue(date: entry.date, value: estimate)
        })
    }

    private func dailyMax(_ points: [DatedValue]) -> [DatedValue] {
        Dictionary(grouping: points) { calendar.startOfDay(for: $0.date) }
            .map { DatedValue(date: $0.key, value: $0.value.map(\.value).max() ?? 0) }
            .sorted { $0.date < $1.date }
    }

    private func target(_ lift: Lift) -> Double { profile?.target(for: lift) ?? 0 }

    private var targetTotal: Double {
        guard let profile else { return 0 }
        return profile.targetTotal > 0 ? profile.targetTotal : profile.targetPullUp + profile.targetDip
    }

    private var currentTotal: Double { best(.pullUp) + best(.dip) }

    private func forecast(_ lift: Lift) -> LiftForecast {
        LiftForecast.make(current: best(lift),
                          target: target(lift),
                          points: dailyMax(attemptPoints(lift) + estimatePoints(lift)),
                          competition: competition)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    goalCard
                    recordsCard
                    chartCard
                    forecastCard
                    attemptsPlanCard
                    historyCard
                    StreetliftingInfoCard()
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Мастер спорта")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingNewAttempt = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Добавить попытку")
                }
            }
            .sheet(isPresented: $showingNewAttempt) {
                AttemptEditorView()
            }
        }
    }

    // MARK: Cards

    private var goalCard: some View {
        let phase = PrepPhase.make(competition: competition, calendar: calendar)
        return Card(title: "Цель: норматив МС", systemImage: "flag.checkered") {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile?.weightClass.isEmpty == false ? profile!.weightClass : "Весовая не указана")
                        .font(.title3.weight(.semibold))
                    if let competition {
                        Text([profile?.competitionName ?? "", competition.shortRu].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let countdown = phase.countdownText {
                    Text(countdown)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                }
            }
            Divider()
            Text(phase.title).font(.subheadline.weight(.semibold))
            Text(phase.advice).font(.subheadline).foregroundStyle(.secondary)
            if profile?.hasTargets != true {
                Label("Укажите норматив МС для своей весовой категории во вкладке «Профиль». Актуальные значения смотрите в ЕВСК и положении о соревнованиях.",
                      systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var recordsCard: some View {
        Card(title: "Рекорды на 1 раз (отягощение)", systemImage: "trophy") {
            TargetProgressRow(title: "Сумма двоеборья", current: currentTotal, target: targetTotal)
            ForEach(Lift.allCases) { lift in
                TargetProgressRow(title: lift.title, current: best(lift), target: target(lift))
            }
            Divider()
            HStack {
                ForEach(Lift.allCases) { lift in
                    StatTile(title: "\(lift.title) / вес тела",
                             value: TargetMath.relativeStrength(added: best(lift), bodyweight: bodyweight)
                                .map { String(format: "%.2f×", $0) } ?? "—")
                }
                StatTile(title: "Вес тела", value: Format.kg(bodyweight))
            }
            if best(.pullUp) > 0, best(.dip) > 0 {
                Text("Соотношение брусья / подтягивания: \(String(format: "%.2f", best(.dip) / best(.pullUp)))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var chartCard: some View {
        Card(title: "Динамика", systemImage: "chart.xyaxis.line") {
            Picker("Движение", selection: $chartLift) {
                ForEach(Lift.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            let attemptsData = attemptPoints(chartLift)
            let estimatesData = estimatePoints(chartLift)
            if attemptsData.isEmpty && estimatesData.isEmpty {
                Text("Добавьте попытку на 1ПМ (кнопка «+») или запишите в дневник подходы с отягощением — график построится автоматически.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                LiftChart(attempts: attemptsData,
                          estimates: estimatesData,
                          target: target(chartLift),
                          trend: forecast(chartLift).trend,
                          competition: competition)
            }
        }
    }

    private var forecastCard: some View {
        Card(title: "Прогноз", systemImage: "scope") {
            ForEach(Lift.allCases) { lift in
                ForecastRow(lift: lift, forecast: forecast(lift))
                if lift != Lift.allCases.last { Divider() }
            }
            Text("Тренд — линейная регрессия по лучшим результатам дня (попытки на 1ПМ и расчётные 1ПМ из дневника).")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var attemptsPlanCard: some View {
        Card(title: "Подходы на помосте", systemImage: "list.number") {
            ForEach(Lift.allCases) { lift in
                let plan = AttemptPlanner.plan(currentMax: best(lift))
                HStack {
                    Text(lift.title).frame(width: 120, alignment: .leading)
                    if plan.isEmpty {
                        Text("нет рекорда").foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(plan.enumerated()), id: \.offset) { index, weight in
                            VStack(spacing: 2) {
                                Text("\(index + 1)-й").font(.caption2).foregroundStyle(.secondary)
                                Text(Format.kg(weight)).font(.subheadline.weight(.semibold)).monospacedDigit()
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            Text("Первый ≈92% от рекорда (уверенный зачёт), второй ≈97%, третий ≈101% — попытка на рекорд. Шаг 1,25 кг.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var historyCard: some View {
        Card(title: "Последние попытки", systemImage: "clock.arrow.circlepath") {
            if attempts.isEmpty {
                Text("Пока пусто").foregroundStyle(.secondary)
            } else {
                ForEach(Array(attempts.suffix(5).reversed())) { attempt in
                    AttemptRow(attempt: attempt)
                }
                NavigationLink("Все попытки (\(attempts.count))") { AttemptsListView() }
                    .font(.subheadline.weight(.semibold))
            }
        }
    }
}

struct ForecastRow: View {
    let lift: Lift
    let forecast: LiftForecast

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(lift.title, systemImage: lift.symbol).font(.subheadline.weight(.semibold))
                Spacer()
                Text(statusText)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusColor.opacity(0.15), in: Capsule())
                    .foregroundStyle(statusColor)
            }
            if let trend = forecast.trend {
                Text("Темп: \(Format.signedKg(trend.slopePerWeek)) в неделю")
                    .font(.subheadline)
            }
            if let reach = forecast.reachDate, forecast.status != .reached {
                Text("Норматив по тренду: ~\(reach.shortRu)").font(.subheadline)
            }
            if let needed = forecast.neededPerWeek {
                Text("Нужно прибавлять: \(Format.kg(needed)) в неделю до старта")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusText: String {
        switch forecast.status {
        case .reached: "Выполнен"
        case .onTrack: "Успеваете"
        case .behind: forecast.target > 0 ? "Отстаёте" : "Нет цели"
        case .projected: "По тренду"
        case .notEnoughData: "Мало данных"
        }
    }

    private var statusColor: Color {
        switch forecast.status {
        case .reached, .onTrack: .green
        case .behind: .orange
        case .projected: .blue
        case .notEnoughData: .gray
        }
    }
}

struct LiftChart: View {
    let attempts: [DatedValue]
    let estimates: [DatedValue]
    let target: Double
    let trend: LinearTrend?
    let competition: Date?

    private var trendRange: (Date, Date)? {
        let dates = (attempts + estimates).map(\.date)
        guard trend != nil, let first = dates.min(), let last = dates.max() else { return nil }
        if let competition, competition > last { return (first, competition) }
        return (first, last)
    }

    var body: some View {
        Chart {
            ForEach(attempts) { point in
                LineMark(x: .value("Дата", point.date), y: .value("кг", point.value), series: .value("Тип", "1ПМ"))
                    .foregroundStyle(by: .value("Тип", "1ПМ"))
                PointMark(x: .value("Дата", point.date), y: .value("кг", point.value))
                    .foregroundStyle(by: .value("Тип", "1ПМ"))
            }
            ForEach(estimates) { point in
                PointMark(x: .value("Дата", point.date), y: .value("кг", point.value))
                    .foregroundStyle(by: .value("Тип", "Расчёт"))
                    .symbol(.diamond)
            }
            if let trend, let range = trendRange {
                ForEach([range.0, range.1], id: \.self) { date in
                    LineMark(x: .value("Дата", date), y: .value("кг", trend.value(at: date)), series: .value("Тип", "Тренд"))
                        .foregroundStyle(by: .value("Тип", "Тренд"))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                }
            }
            if target > 0 {
                RuleMark(y: .value("Норматив", target))
                    .foregroundStyle(.green)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .annotation(position: .top, alignment: .leading) {
                        Text("Норматив \(Format.kg(target))").font(.caption2).foregroundStyle(.green)
                    }
            }
        }
        .chartForegroundStyleScale(["1ПМ": Color.accentColor, "Расчёт": Color.orange, "Тренд": Color.gray])
        .chartYAxisLabel("кг")
        .frame(height: 230)
    }
}

struct StreetliftingInfoCard: View {
    var body: some View {
        Card(title: "Стритлифтинг: коротко", systemImage: "info.circle") {
            DisclosureGroup("Дисциплина") {
                Text("Силовое двоеборье: подтягивания на перекладине и отжимания на брусьях с отягощением на один раз. Результат — вес отягощения; в зачёт идёт лучший успешный подход в каждом движении и их сумма. Каждому спортсмену обычно даётся по три подхода в движении.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            DisclosureGroup("Подтягивания — частые ошибки") {
                Text("Старт из виса на прямых руках, подбородок выше перекладины, без раскачки и рывков ногами, опускание до полного выпрямления рук по команде судьи.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            DisclosureGroup("Брусья — частые ошибки") {
                Text("Старт с выпрямленных рук, опускание до положения, когда плечевой сустав ниже локтя, полное выпрямление рук наверху, без «дёрганья» ногами, фиксация по команде.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            Text("Правила и нормативы различаются по федерациям и годам — сверяйтесь с актуальным положением и ЕВСК.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
