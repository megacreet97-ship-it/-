import Charts
import SwiftData
import SwiftUI

struct MasterView: View {
    @Query(sort: \MaxAttempt.date) private var attempts: [MaxAttempt]
    @Query(sort: \WorkoutEntry.date) private var entries: [WorkoutEntry]
    @Query private var profiles: [AthleteProfile]

    @State private var chartLift: Lift = .pullUp
    @State private var showingNewAttempt = false
    @State private var showingGoalSettings = false

    private let calendar = Calendar.current

    private var profile: AthleteProfile? { profiles.first }
    private var bodyweight: Double { profile?.bodyweight ?? 0 }
    private var competition: Date? { profile?.competitionDate }
    private var federation: Federation { profile?.federation ?? .isf }

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
    private var goalTotal: Double { profile?.goalTotal ?? 0 }
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
                    heroCard
                    HStack(spacing: 12) {
                        ForEach(Lift.allCases) { liftTile($0) }
                    }
                    weightClassesCard
                    chartCard
                    forecastCard
                    attemptsPlanCard
                    historyCard
                    StreetliftingInfoCard()
                    Button { showingGoalSettings = true } label: {
                        Label("Другая цель: похудение, рекомпозиция, набор мышц", systemImage: "target")
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(.vertical, 4)
                }
                .padding()
            }
            .scrollIndicators(.hidden)
            .background(Color(.systemBackground))
            .navigationTitle("Мастер спорта")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingNewAttempt = true } label: {
                        Label("Попытка", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }
            .sheet(isPresented: $showingNewAttempt) {
                AttemptEditorView()
            }
            .sheet(isPresented: $showingGoalSettings) {
                if let profile { GoalSettingsSheet(profile: profile, hasStreetliftingData: true) }
            }
        }
    }

    // MARK: Hero

    private var heroCard: some View {
        let phase = PrepPhase.make(competition: competition, calendar: calendar)
        let progress = TargetMath.fraction(current: currentTotal, target: goalTotal)
        let achieved = profile?.standard?.achievedRank(total: currentTotal)
        return VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 6) {
                Pill(text: "Цель: \(profile?.goalRank.title ?? "МС")", systemImage: "flag.checkered", tint: Theme.orange)
                if profile?.standard != nil {
                    Pill(text: federation.title, tint: .secondary)
                }
                Pill(text: profile?.weightClass.isEmpty == false ? profile!.weightClass : "своя цель", tint: .secondary)
                Spacer(minLength: 0)
            }

            HStack(spacing: 20) {
                ZStack {
                    RingProgress(progress: progress, lineWidth: 16)
                    VStack(spacing: 0) {
                        Text(Format.number(currentTotal))
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text(goalTotal > 0 ? "из \(Format.number(goalTotal)) кг" : "кг")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 136, height: 136)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Сумма двоеборья").font(.subheadline).foregroundStyle(.secondary)
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.accentGradient)
                    if goalTotal > 0 {
                        Text(currentTotal >= goalTotal ? "Норматив выполнен" : "Осталось \(Format.kg(goalTotal - currentTotal))")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(currentTotal >= goalTotal ? Theme.green : Color.primary)
                    } else {
                        Text("Выберите норматив в профиле").font(.footnote).foregroundStyle(Theme.orange)
                    }
                    if let achieved {
                        Pill(text: "\(achieved.title) выполнен", systemImage: "checkmark.seal.fill", tint: achieved.color)
                    }
                }
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(phase.title).font(.subheadline.weight(.semibold))
                    Spacer()
                    if let countdown = phase.countdownText {
                        Pill(text: countdown, systemImage: "calendar", tint: Theme.pink)
                    }
                }
                Text(phase.advice).font(.footnote).foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Theme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(LinearGradient(colors: [Theme.orange.opacity(0.28), Theme.pink.opacity(0.1), .clear],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                )
                .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Color.white.opacity(0.08)))
        }
    }

    private func liftTile(_ lift: Lift) -> some View {
        let current = best(lift)
        let goal = target(lift)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                IconBadge(systemImage: lift.symbol, tint: lift.color, size: 36)
                Spacer()
                RingProgress(progress: TargetMath.fraction(current: current, target: goal), lineWidth: 5,
                             colors: [lift.color.opacity(0.6), lift.color])
                    .frame(width: 30, height: 30)
            }
            Text(lift.title).font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("+\(Format.number(current))")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("кг").font(.subheadline).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(goal > 0 ? "цель \(Format.kg(goal))" : "цель не задана")
                if let ratio = TargetMath.relativeStrength(added: current, bodyweight: bodyweight) {
                    Text(String(format: "%.2f× веса тела", ratio).replacingOccurrences(of: ".", with: ","))
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: Weight classes

    private var weightClassesCard: some View {
        Card(title: "Нормативы по весовым · \(federation.title)", systemImage: "scalemass.fill") {
            ForEach(Standards.classes(for: federation)) { standard in
                WeightClassBlock(standard: standard,
                                 total: currentTotal,
                                 isCurrent: standard.contains(bodyweight: bodyweight),
                                 isGoal: profile?.weightClassLimit == standard.limit)
            }
            if let hint = bodyweightHint {
                Label(hint, systemImage: "lightbulb.fill")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            NavigationLink {
                StandardsView(initialFederation: federation, total: currentTotal, pullUp: best(.pullUp), dip: best(.dip))
            } label: {
                HStack {
                    Text("Все нормативы: подтягивания, брусья, сумма")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.orange)
            }
        }
    }

    private var bodyweightHint: String? {
        let classes = Standards.classes(for: federation)
        guard bodyweight > 0, let lightest = classes.first, let heaviest = classes.last else { return nil }
        if bodyweight > heaviest.limit {
            return "Ваш вес \(Format.kg(bodyweight)) — выше \(Format.kg(heaviest.limit)). Для тяжёлых категорий задайте свою цель в профиле."
        }
        let current = Standards.classFor(bodyweight: bodyweight, federation: federation) ?? lightest
        if current.limit > lightest.limit,
           let currentMS = current.norms(for: .ms)?.total,
           let lightMS = lightest.norms(for: .ms)?.total {
            return "До категории \(lightest.title) нужно снизить вес на \(Format.kg(bodyweight - lightest.limit)) — норматив МС там на \(Format.kg(currentMS - lightMS)) ниже."
        }
        return "При весе \(Format.kg(bodyweight)) вы выступаете в категории \(current.title)."
    }

    // MARK: Chart

    private var chartCard: some View {
        Card(title: "Динамика рекордов", systemImage: "chart.xyaxis.line") {
            SegmentedCapsules(items: Lift.allCases, selection: $chartLift) { $0.title }

            let attemptsData = attemptPoints(chartLift)
            let estimatesData = estimatePoints(chartLift)
            if attemptsData.isEmpty && estimatesData.isEmpty {
                Text("Добавьте попытку на 1 раз (кнопка «Попытка») или запишите в дневник подходы с отягощением — график построится автоматически.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                LiftChart(attempts: attemptsData,
                          estimates: estimatesData,
                          target: target(chartLift),
                          trend: forecast(chartLift).trend,
                          competition: competition,
                          color: chartLift.color)
                HStack(spacing: 14) {
                    legend(color: chartLift.color, text: "Рекорд")
                    legend(color: Theme.orange, text: "Расчёт из дневника")
                    legend(color: .gray, text: "Тренд")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func legend(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text)
        }
    }

    // MARK: Forecast & plan

    private var forecastCard: some View {
        Card(title: "Прогноз", systemImage: "scope") {
            ForEach(Lift.allCases) { lift in
                ForecastRow(lift: lift, forecast: forecast(lift))
                if lift != Lift.allCases.last { Divider().overlay(Color.white.opacity(0.08)) }
            }
            Text("Тренд — линейная регрессия по лучшим результатам дня (попытки и расчётные максимумы из дневника). Цели по движениям — раскладка норматива суммы.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var attemptsPlanCard: some View {
        Card(title: "Подходы на помосте", systemImage: "list.number") {
            ForEach(Lift.allCases) { lift in
                let plan = AttemptPlanner.plan(currentMax: best(lift))
                VStack(alignment: .leading, spacing: 8) {
                    Text(lift.title).font(.subheadline.weight(.semibold)).foregroundStyle(lift.color)
                    if plan.isEmpty {
                        Text("Нет рекорда — добавьте попытку").font(.footnote).foregroundStyle(.secondary)
                    } else {
                        HStack(spacing: 8) {
                            ForEach(Array(plan.enumerated()), id: \.offset) { index, weight in
                                VStack(spacing: 2) {
                                    Text("\(index + 1)-й").font(.caption2).foregroundStyle(.secondary)
                                    Text(Format.number(weight))
                                        .font(.system(.headline, design: .rounded))
                                        .monospacedDigit()
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(lift.color.opacity(index == 2 ? 0.25 : 0.1),
                                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                        }
                    }
                }
            }
            Text("1-й ≈92% от рекорда (уверенный зачёт), 2-й ≈97%, 3-й ≈101% — на рекорд. Шаг 1,25 кг.")
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
                NavigationLink {
                    AttemptsListView()
                } label: {
                    HStack {
                        Text("Все попытки (\(attempts.count))")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.orange)
                }
            }
        }
    }
}

struct WeightClassBlock: View {
    let standard: WeightClassStandard
    let total: Double
    let isCurrent: Bool
    let isGoal: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(standard.title).font(.headline)
                if isCurrent { Pill(text: "ваш вес", systemImage: "person.fill", tint: Theme.green) }
                if isGoal { Pill(text: "цель", systemImage: "flag.fill", tint: Theme.orange) }
                Spacer()
            }
            ForEach(SportRank.allCases) { rank in
                if let norm = standard.norms(for: rank)?.total {
                    HStack(spacing: 10) {
                        Text(rank.title)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(rank.color)
                            .frame(width: 44, alignment: .leading)
                        ProgressBar(fraction: TargetMath.fraction(current: total, target: norm),
                                    tint: total >= norm ? Theme.green : rank.color, height: 6)
                        Text(Format.number(norm))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .frame(width: 48, alignment: .trailing)
                        Group {
                            if total >= norm {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.green)
                            } else {
                                Text("−\(Format.number(norm - total))").foregroundStyle(.secondary)
                            }
                        }
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .frame(width: 48, alignment: .trailing)
                    }
                }
            }
        }
        .padding(14)
        .background(isGoal ? Theme.orange.opacity(0.08) : Color.white.opacity(0.03),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isGoal ? Theme.orange.opacity(0.4) : Color.clear)
        )
    }
}

struct ForecastRow: View {
    let lift: Lift
    let forecast: LiftForecast

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(lift.title, systemImage: lift.symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(lift.color)
                Spacer()
                Pill(text: statusText, tint: statusColor)
            }
            if let trend = forecast.trend {
                Text("Темп: \(Format.signedKg(trend.slopePerWeek)) в неделю").font(.subheadline)
            }
            if let reach = forecast.reachDate, forecast.status != .reached {
                Text("Цель по тренду: ~\(reach.shortRu)").font(.subheadline)
            }
            if let needed = forecast.neededPerWeek {
                Text("Нужно прибавлять \(Format.kg(needed)) в неделю до старта")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusText: String {
        switch forecast.status {
        case .reached: "Выполнено"
        case .onTrack: "Успеваете"
        case .behind: forecast.target > 0 ? "Отстаёте" : "Нет цели"
        case .projected: "По тренду"
        case .notEnoughData: "Мало данных"
        }
    }

    private var statusColor: Color {
        switch forecast.status {
        case .reached, .onTrack: Theme.green
        case .behind: Theme.orange
        case .projected: Theme.blue
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
    let color: Color

    private var trendRange: (Date, Date)? {
        let dates = (attempts + estimates).map(\.date)
        guard trend != nil, let first = dates.min(), let last = dates.max() else { return nil }
        if let competition, competition > last { return (first, competition) }
        return (first, last)
    }

    private var yDomain: ClosedRange<Double> {
        var values = (attempts + estimates).map(\.value)
        if target > 0 { values.append(target) }
        if let trend, let range = trendRange {
            values.append(trend.value(at: range.0))
            values.append(trend.value(at: range.1))
        }
        let low = max((values.min() ?? 0) - 5, 0)
        let high = (values.max() ?? 10) + 5
        return low...high
    }

    var body: some View {
        Chart {
            ForEach(attempts) { point in
                AreaMark(x: .value("Дата", point.date),
                         yStart: .value("Мин", yDomain.lowerBound),
                         yEnd: .value("кг", point.value))
                    .foregroundStyle(LinearGradient(colors: [color.opacity(0.35), color.opacity(0)], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.monotone)
                LineMark(x: .value("Дата", point.date), y: .value("кг", point.value), series: .value("Тип", "Рекорд"))
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    .interpolationMethod(.monotone)
                PointMark(x: .value("Дата", point.date), y: .value("кг", point.value))
                    .foregroundStyle(color)
                    .symbolSize(40)
            }
            ForEach(estimates) { point in
                PointMark(x: .value("Дата", point.date), y: .value("кг", point.value))
                    .foregroundStyle(Theme.orange.opacity(0.8))
                    .symbol(.diamond)
                    .symbolSize(30)
            }
            if let trend, let range = trendRange {
                ForEach([range.0, range.1], id: \.self) { date in
                    LineMark(x: .value("Дата", date), y: .value("кг", trend.value(at: date)), series: .value("Тип", "Тренд"))
                        .foregroundStyle(Color.gray)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                }
            }
            if target > 0 {
                RuleMark(y: .value("Цель", target))
                    .foregroundStyle(Theme.green)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .annotation(position: .top, alignment: .leading) {
                        Text("цель \(Format.kg(target))").font(.caption2.weight(.semibold)).foregroundStyle(Theme.green)
                    }
            }
        }
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing) { _ in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                AxisValueLabel()
            }
        }
        .frame(height: 220)
    }
}

struct StreetliftingInfoCard: View {
    var body: some View {
        Card(title: "Стритлифтинг: коротко", systemImage: "info.circle.fill") {
            infoGroup("Дисциплина",
                      "Двоеборье: подтягивания на перекладине и отжимания на брусьях с отягощением на один раз. Результат — вес отягощения, в зачёт идёт лучший успешный подход в каждом движении и их сумма. Обычно по три подхода в движении.")
            infoGroup("Звания",
                      "Стритлифтинг не входит в ЕВСК: КМС, МС и МСМК присваивают федерации (ISF-Россия, WSF) по своим таблицам. Звание в двоеборье даётся по сумме; нормативы в подтягиваниях и брусьях — для отдельных дисциплин.")
            infoGroup("Подтягивания — частые ошибки",
                      "Старт из виса на прямых руках, подбородок выше перекладины, без раскачки и рывков ногами, опускание до полного выпрямления рук по команде судьи.")
            infoGroup("Брусья — частые ошибки",
                      "Старт с выпрямленных рук, опускание до положения, когда плечевой сустав ниже локтя, полное выпрямление рук наверху, без рывков ногами, фиксация по команде.")
        }
        .tint(Theme.orange)
    }

    private func infoGroup(_ title: String, _ text: String) -> some View {
        DisclosureGroup(title) {
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
        }
        .foregroundStyle(.primary)
    }
}
