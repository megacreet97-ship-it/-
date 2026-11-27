import Foundation

enum Goal: String, CaseIterable, Identifiable {
    case ms, recomp, fatLoss, muscle

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ms: "Мастер спорта"
        case .recomp: "Рекомпозиция"
        case .fatLoss: "Похудение"
        case .muscle: "Набор мышц"
        }
    }

    var subtitle: String {
        switch self {
        case .ms: "Стритлифтинг: подтягивания и брусья с весом на 1 раз"
        case .recomp: "Минус жир, плюс мышцы — вес почти не меняется, а фигура становится подтянутой"
        case .fatLoss: "Снизить вес за счёт жира и сохранить мышцы"
        case .muscle: "Больше мышц и силы с минимумом лишнего жира"
        }
    }

    var symbol: String {
        switch self {
        case .ms: "trophy.fill"
        case .recomp: "sparkles"
        case .fatLoss: "chart.line.downtrend.xyaxis"
        case .muscle: "chart.line.uptrend.xyaxis"
        }
    }
}

struct GoalVerdict: Equatable {
    enum Tone { case good, warn, neutral }
    let title: String
    let text: String
    let tone: Tone
}

struct GoalTip: Identifiable {
    let title: String
    let text: String
    var id: String { title }
}

enum BodyMath {
    /// Mean of the values in the 7 days up to the latest one: smooths out water and food swings.
    static func smoothedLatest(_ points: [DatedValue]) -> Double? {
        guard let last = points.max(by: { $0.date < $1.date })?.date else { return nil }
        let recent = points.filter { $0.date > last.addingTimeInterval(-7 * 86_400) }
        return recent.map(\.value).reduce(0, +) / Double(recent.count)
    }

    static func recentTrend(_ points: [DatedValue], days: Int = 28, now: Date = .now, calendar: Calendar = .current) -> LinearTrend? {
        guard let from = calendar.date(byAdding: .day, value: -days + 1, to: calendar.startOfDay(for: now)) else { return nil }
        let recent = points.filter { $0.date >= from }.sorted { $0.date < $1.date }
        guard let first = recent.first, let last = recent.last, recent.count >= 2,
              last.date.timeIntervalSince(first.date) >= 6 * 86_400 else { return nil }
        return LinearTrend(points: recent)
    }

    /// Change per week from a linear trend over the last `days`; nil until the data spans at least 6 days.
    static func weeklyRate(_ points: [DatedValue], days: Int = 28, now: Date = .now, calendar: Calendar = .current) -> Double? {
        recentTrend(points, days: days, now: now, calendar: calendar)?.slopePerWeek
    }

    /// Rates follow common guidance: fat loss 0.5–1% of bodyweight a week, lean gain 0.25–0.5%,
    /// recomposition keeps weight within about ±0.3% while the waist goes down.
    static func verdict(goal: Goal, weight: Double?, weightPerWeek: Double?, waistPerWeek: Double?) -> GoalVerdict {
        guard let weight, let weightPerWeek, weight > 0 else {
            return GoalVerdict(title: "Нужно больше замеров",
                               text: "Взвешивайтесь 2–3 раза в неделю утром натощак — через неделю появится темп и оценка.", tone: .neutral)
        }
        let pct = weightPerWeek / weight * 100
        let waistDown = (waistPerWeek ?? 0) < -0.05
        let waistUp = (waistPerWeek ?? 0) > 0.05
        switch goal {
        case .fatLoss:
            if pct < -1 { return GoalVerdict(title: "Слишком быстро", text: "Больше 1% веса в неделю — растёт риск потерять мышцы. Добавьте немного калорий и держите белок.", tone: .warn) }
            if pct <= -0.5 { return GoalVerdict(title: "Оптимальный темп", text: "Вес уходит на 0,5–1% в неделю — так уходит в основном жир. Продолжайте.", tone: .good) }
            if pct < -0.1 { return GoalVerdict(title: "Медленно, но верно", text: "Вес снижается. Для темпа побыстрее уберите 100–200 ккал или добавьте шагов.", tone: .good) }
            if waistDown { return GoalVerdict(title: "Вес стоит, талия уходит", text: "Жир уходит, а мышцы растут — это хороший знак, продолжайте.", tone: .good) }
            return GoalVerdict(title: pct > 0.1 ? "Вес растёт" : "Вес стоит", text: "Нужен небольшой дефицит: уберите 200–300 ккал в день или добавьте 2–3 тысячи шагов.", tone: .warn)
        case .muscle:
            if pct > 0.5 { return GoalVerdict(title: "Слишком быстро", text: "Больше 0,5% веса в неделю — вместе с мышцами копится жир. Уберите 100–200 ккал.", tone: .warn) }
            if pct >= 0.2 { return GoalVerdict(title: "Оптимальный темп", text: "Плюс 0,25–0,5% веса в неделю — хороший темп набора мышц. Прибавляйте в рабочих весах.", tone: .good) }
            if pct >= -0.1 { return GoalVerdict(title: "Вес почти не растёт", text: "Для набора мышц добавьте 200–300 ккал в день, например перекус с белком.", tone: .neutral) }
            return GoalVerdict(title: "Вес снижается", text: "При наборе мышц вес должен понемногу расти — ешьте больше.", tone: .warn)
        case .recomp:
            if pct < -1 { return GoalVerdict(title: "Вес уходит слишком быстро", text: "Для рекомпозиции дефицит должен быть небольшим, иначе мышцам не из чего расти. Добавьте калорий.", tone: .warn) }
            if abs(pct) <= 0.3 && waistDown { return GoalVerdict(title: "Идёт рекомпозиция", text: "Вес стабилен, талия уменьшается — жир уходит, мышцы растут. Так и держать.", tone: .good) }
            if pct < -0.3 && !waistUp { return GoalVerdict(title: "Жир уходит", text: "Вес плавно снижается. Если силовые растут — мышцы сохраняются, всё идёт хорошо.", tone: .good) }
            if waistUp || pct > 0.3 { return GoalVerdict(title: "Талия или вес растут", text: "Проверьте питание: при рекомпозиции калории около нормы или чуть ниже, белок каждый день.", tone: .warn) }
            if waistPerWeek == nil { return GoalVerdict(title: "Вес стабилен", text: "Для рекомпозиции важна талия: добавляйте её в замеры раз в неделю.", tone: .neutral) }
            return GoalVerdict(title: "Вес и талия стабильны", text: "Прибавляйте в весах на тренировках и держите белок — изменения придут.", tone: .neutral)
        case .ms:
            return GoalVerdict(title: "", text: "", tone: .neutral)
        }
    }

    /// Protein guidance for people who lift: 1.6–2.2 g per kg of bodyweight, rounded to 5 g.
    static func proteinRange(weight: Double) -> ClosedRange<Int> {
        let low = Int((weight * 1.6 / 5).rounded()) * 5
        let high = Int((weight * 2.2 / 5).rounded()) * 5
        return low...max(low, high)
    }

    /// Date the target weight is reached at the current rate, if the rate points towards it.
    static func reachDate(current: Double, target: Double, perWeek: Double?, now: Date = .now) -> Date? {
        guard let perWeek, perWeek != 0, target > 0, abs(target - current) >= 0.05 else { return nil }
        let weeks = (target - current) / perWeek
        guard weeks > 0, weeks <= 156 else { return nil }
        return now.addingTimeInterval(weeks * 7 * 86_400)
    }

    static func targetProgress(start: Double, current: Double, target: Double) -> Double {
        guard target > 0, start > 0, start != target else { return 0 }
        return min(max((current - start) / (target - start), 0), 1)
    }

    static func plan(goal: Goal, weight: Double, workouts: Int) -> [GoalTip] {
        let protein = proteinRange(weight: weight)
        let proteinTip = GoalTip(title: "Белок", text: "\(protein.lowerBound)–\(protein.upperBound) г в день (1,6–2,2 г на кг веса) — главное, чтобы мышцы сохранялись и росли.")
        let training = GoalTip(title: "Силовые", text: "\(workouts) тренировки в неделю, 10–20 рабочих подходов на каждую крупную мышцу. Каждые 1–2 недели прибавляйте вес или повторения.")
        let sleep = GoalTip(title: "Сон", text: "7–9 часов. При недосыпе хуже уходит жир и медленнее растут мышцы.")
        switch goal {
        case .fatLoss:
            return [GoalTip(title: "Питание", text: "Дефицит 300–500 ккал от нормы. Без голодовок: резкий дефицит забирает мышцы."),
                    proteinTip, training,
                    GoalTip(title: "Активность", text: "8–10 тысяч шагов в день и 1–2 кардио по 20–30 минут."),
                    sleep]
        case .muscle:
            return [GoalTip(title: "Питание", text: "Профицит 200–300 ккал от нормы. Больше — лишний жир, а мышцы быстрее не растут."),
                    proteinTip, training,
                    GoalTip(title: "Прогрессия", text: "Главный сигнал для роста — постепенный рост рабочих весов. Записывайте каждую тренировку."),
                    sleep]
        case .recomp, .ms:
            return [GoalTip(title: "Питание", text: "Калории около нормы или дефицит до 200–300 ккал. Вес почти не меняется — это нормально."),
                    proteinTip, training,
                    GoalTip(title: "Как следить", text: "Смотрите на талию и рабочие веса, а не только на весы: жир уходит, мышцы прибавляются."),
                    sleep]
        }
    }
}
