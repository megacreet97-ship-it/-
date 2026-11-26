import Foundation

// Pure Foundation-only logic: no SwiftUI/SwiftData so it can be unit-tested on any platform.

enum Lift: String, CaseIterable, Identifiable, Codable {
    case pullUp
    case dip

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pullUp: "Подтягивания"
        case .dip: "Брусья"
        }
    }

    var fullTitle: String {
        switch self {
        case .pullUp: "Подтягивания с отягощением"
        case .dip: "Отжимания на брусьях с отягощением"
        }
    }

    var symbol: String {
        switch self {
        case .pullUp: "figure.climbing"
        case .dip: "figure.strengthtraining.traditional"
        }
    }
}

struct DatedValue: Equatable, Identifiable {
    let date: Date
    let value: Double
    var id: Date { date }
}

// MARK: - 1RM

enum OneRepMax {
    static let maxReliableReps = 12

    static func epley(_ weight: Double, reps: Int) -> Double {
        reps <= 1 ? weight : weight * (1 + Double(reps) / 30)
    }

    static func brzycki(_ weight: Double, reps: Int) -> Double {
        reps <= 1 ? weight : weight * 36 / (37 - Double(reps))
    }

    /// In streetlifting the result is the added weight, but the athlete moves bodyweight + added weight,
    /// so the formulas are applied to the total system weight and bodyweight is subtracted afterwards.
    static func estimatedAddedWeight(added: Double, bodyweight: Double, reps: Int) -> Double? {
        guard reps >= 1, reps <= maxReliableReps, bodyweight > 0, added >= 0 else { return nil }
        if reps == 1 { return added }
        let system = bodyweight + added
        let estimate = (epley(system, reps: reps) + brzycki(system, reps: reps)) / 2
        return estimate - bodyweight
    }
}

// MARK: - Trend

struct LinearTrend {
    let slopePerDay: Double
    let intercept: Double
    let referenceDate: Date

    init?(points: [DatedValue]) {
        guard points.count >= 2 else { return nil }
        let sorted = points.sorted { $0.date < $1.date }
        let reference = sorted[0].date
        let xs = sorted.map { $0.date.timeIntervalSince(reference) / 86_400 }
        let ys = sorted.map(\.value)
        let n = Double(sorted.count)
        let meanX = xs.reduce(0, +) / n
        let meanY = ys.reduce(0, +) / n
        var numerator = 0.0
        var denominator = 0.0
        for (x, y) in zip(xs, ys) {
            numerator += (x - meanX) * (y - meanY)
            denominator += (x - meanX) * (x - meanX)
        }
        guard denominator > 0 else { return nil }
        slopePerDay = numerator / denominator
        intercept = meanY - slopePerDay * meanX
        referenceDate = reference
    }

    var slopePerWeek: Double { slopePerDay * 7 }

    func value(at date: Date) -> Double {
        intercept + slopePerDay * date.timeIntervalSince(referenceDate) / 86_400
    }

    func date(reaching target: Double) -> Date? {
        guard slopePerDay > 0 else { return nil }
        let days = (target - intercept) / slopePerDay
        return referenceDate.addingTimeInterval(days * 86_400)
    }
}

// MARK: - Forecast

struct LiftForecast {
    enum Status: Equatable {
        case reached
        case onTrack
        case behind
        case projected
        case notEnoughData
    }

    let current: Double
    let target: Double
    let trend: LinearTrend?
    let reachDate: Date?
    let neededPerWeek: Double?
    let status: Status

    var remaining: Double { max(target - current, 0) }

    static func make(current: Double,
                     target: Double,
                     points: [DatedValue],
                     today: Date = .now,
                     competition: Date?) -> LiftForecast {
        let trend = LinearTrend(points: points)
        var reachDate: Date?
        if let trend, current < target, let date = trend.date(reaching: target) {
            reachDate = max(date, today)
        }

        var neededPerWeek: Double?
        if let competition, competition > today, current < target {
            let weeks = competition.timeIntervalSince(today) / (7 * 86_400)
            neededPerWeek = weeks > 0 ? (target - current) / weeks : nil
        }

        let status: Status
        if target > 0, current >= target {
            status = .reached
        } else if trend == nil {
            status = .notEnoughData
        } else if let competition {
            if let reachDate, reachDate <= competition { status = .onTrack } else { status = .behind }
        } else {
            status = reachDate == nil ? .behind : .projected
        }

        return LiftForecast(current: current, target: target, trend: trend,
                            reachDate: reachDate, neededPerWeek: neededPerWeek, status: status)
    }
}

enum TargetMath {
    static func fraction(current: Double, target: Double) -> Double {
        guard target > 0 else { return 0 }
        return min(max(current / target, 0), 1)
    }

    static func relativeStrength(added: Double, bodyweight: Double) -> Double? {
        bodyweight > 0 ? added / bodyweight : nil
    }
}

// MARK: - Competition attempts

enum AttemptPlanner {
    static let defaultStep = 1.25

    static func round(_ value: Double, step: Double = defaultStep) -> Double {
        (value / step).rounded() * step
    }

    /// Opener ~92%, second ~97%, third ~101% of the current best, each strictly heavier than the previous.
    static func plan(currentMax: Double, step: Double = defaultStep) -> [Double] {
        guard currentMax > 0 else { return [] }
        var result: [Double] = []
        for percent in [0.92, 0.97, 1.01] {
            var value = round(currentMax * percent, step: step)
            if let last = result.last, value <= last { value = last + step }
            result.append(value)
        }
        return result
    }
}

// MARK: - Preparation phase

enum PrepPhase: Equatable {
    case noDate
    case offSeason(weeks: Int)
    case base(weeks: Int)
    case strength(weeks: Int)
    case peaking(days: Int)
    case taper(days: Int)
    case competitionDay
    case past

    static func make(today: Date = .now, competition: Date?, calendar: Calendar = .current) -> PrepPhase {
        guard let competition else { return .noDate }
        let start = calendar.startOfDay(for: today)
        let end = calendar.startOfDay(for: competition)
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        let weeks = days / 7
        switch days {
        case ..<0: return .past
        case 0: return .competitionDay
        case 1...10: return .taper(days: days)
        case 11...28: return .peaking(days: days)
        case 29...56: return .strength(weeks: weeks)
        case 57...112: return .base(weeks: weeks)
        default: return .offSeason(weeks: weeks)
        }
    }

    var title: String {
        switch self {
        case .noDate: "Дата старта не задана"
        case .offSeason: "Межсезонье"
        case .base: "Базовый (объёмный) блок"
        case .strength: "Силовой блок"
        case .peaking: "Подводка (пикинг)"
        case .taper: "Разгрузка перед стартом"
        case .competitionDay: "День соревнований"
        case .past: "Старт прошёл"
        }
    }

    var advice: String {
        switch self {
        case .noDate:
            "Укажите дату соревнований в профиле — приложение рассчитает фазу подготовки и нужный темп прироста."
        case .offSeason:
            "Наращивайте объём: подходы по 6–10 повторений с отягощением 60–75% от 1ПМ, подсобка на спину, трицепс и грудь."
        case .base:
            "Объём и техника: 4–6 подходов по 4–6 повторений на 70–80% от 1ПМ, 2–3 тренировки в неделю на каждое движение."
        case .strength:
            "Интенсивность растёт: 3–5 подходов по 2–4 повторения на 80–90%, объём постепенно снижается."
        case .peaking:
            "Тяжёлые одиночки и двойки на 90–97%, отработка соревновательной техники и команд судьи, объём минимальный."
        case .taper:
            "Снижайте нагрузку на 40–60%, лёгкие разминочные подходы, сон и восстановление. Новых рекордов не ищите."
        case .competitionDay:
            "Удачи на помосте! Начинайте с уверенного первого подхода."
        case .past:
            "Запишите результаты соревнований как попытки и задайте дату следующего старта."
        }
    }

    var countdownText: String? {
        switch self {
        case .offSeason(let w), .base(let w), .strength(let w): "≈ \(w) нед. до старта"
        case .peaking(let d), .taper(let d): "\(d) дн. до старта"
        case .competitionDay: "Сегодня!"
        case .noDate, .past: nil
        }
    }
}

// MARK: - Diary analytics

struct LogItem {
    let date: Date
    let exercise: String
    let reps: Int
    let sets: Int
    let addedWeight: Double
    /// Reps of each set when they differ (e.g. 8, 8, 8, 3); `reps` then holds the best set.
    var setReps: [Int]? = nil

    var totalReps: Int {
        if let setReps, !setReps.isEmpty { return setReps.reduce(0, +) }
        return reps * sets
    }
    var tonnage: Double { addedWeight * Double(totalReps) }
}

enum SetsFormat {
    /// "4 × 8" when all sets are equal, otherwise "8, 8, 8, 3".
    static func label(sets: Int, reps: Int, setReps: [Int]?) -> String {
        if let list = setReps, let first = list.first {
            if list.contains(where: { $0 != first }) { return list.map(String.init).joined(separator: ", ") }
            return "\(list.count) × \(first)"
        }
        return "\(sets) × \(reps)"
    }

    /// Equal sets collapse to plain sets × reps; otherwise `reps` is the best set.
    static func normalize(_ list: [Int]) -> (sets: Int, reps: Int, setReps: [Int]?) {
        let clean = list.filter { $0 > 0 }
        guard let first = clean.first else { return (1, 1, nil) }
        if clean.allSatisfy({ $0 == first }) { return (clean.count, first, nil) }
        return (clean.count, clean.max() ?? first, clean)
    }
}

struct ExerciseTotal: Identifiable, Equatable {
    let name: String
    let totalReps: Int
    let totalSets: Int
    let sessions: Int
    let maxWeight: Double
    var id: String { name }
}

enum DiaryAnalytics {
    static func totalReps(_ items: [LogItem]) -> Int {
        items.reduce(0) { $0 + $1.totalReps }
    }

    static func totalSets(_ items: [LogItem]) -> Int {
        items.reduce(0) { $0 + $1.sets }
    }

    static func weekStart(for date: Date, calendar: Calendar = .current) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    static func weeklyReps(_ items: [LogItem], calendar: Calendar = .current) -> [DatedValue] {
        var buckets: [Date: Double] = [:]
        for item in items {
            buckets[weekStart(for: item.date, calendar: calendar), default: 0] += Double(item.totalReps)
        }
        return buckets.map { DatedValue(date: $0.key, value: $0.value) }.sorted { $0.date < $1.date }
    }

    static func trainingDays(_ items: [LogItem], calendar: Calendar = .current) -> Set<Date> {
        Set(items.map { calendar.startOfDay(for: $0.date) })
    }

    /// Consecutive training days ending today (or yesterday, so the streak is not lost before today's workout).
    static func currentStreak(days: Set<Date>, today: Date = .now, calendar: Calendar = .current) -> Int {
        var cursor = calendar.startOfDay(for: today)
        if !days.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor),
                  days.contains(yesterday) else { return 0 }
            cursor = yesterday
        }
        var streak = 0
        while days.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    static func longestStreak(days: Set<Date>, calendar: Calendar = .current) -> Int {
        let sorted = days.sorted()
        var best = 0
        var current = 0
        var previous: Date?
        for day in sorted {
            if let previous, calendar.date(byAdding: .day, value: 1, to: previous) == day {
                current += 1
            } else {
                current = 1
            }
            best = max(best, current)
            previous = day
        }
        return best
    }

    static func exerciseTotals(_ items: [LogItem], calendar: Calendar = .current) -> [ExerciseTotal] {
        Dictionary(grouping: items, by: \.exercise)
            .map { name, group in
                ExerciseTotal(name: name,
                              totalReps: totalReps(group),
                              totalSets: totalSets(group),
                              sessions: trainingDays(group, calendar: calendar).count,
                              maxWeight: group.map(\.addedWeight).max() ?? 0)
            }
            .sorted { $0.totalReps == $1.totalReps ? $0.name < $1.name : $0.totalReps > $1.totalReps }
    }

    /// Per-day best value for one exercise: max added weight if weighted, otherwise total reps.
    static func dailyProgress(_ items: [LogItem], exercise: String, calendar: Calendar = .current) -> [DatedValue] {
        let filtered = items.filter { $0.exercise == exercise }
        let weighted = filtered.contains { $0.addedWeight > 0 }
        let grouped = Dictionary(grouping: filtered) { calendar.startOfDay(for: $0.date) }
        return grouped.map { day, group in
            let value = weighted
                ? group.map(\.addedWeight).max() ?? 0
                : Double(totalReps(group))
            return DatedValue(date: day, value: value)
        }
        .sorted { $0.date < $1.date }
    }
}

enum Format {
    static func number(_ value: Double) -> String {
        let rounded = (value * 100).rounded() / 100
        return rounded.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(rounded))
            : String(format: "%.2f", rounded)
                .replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: ".", with: ",")
    }

    static func kg(_ value: Double) -> String {
        "\(number(value)) кг"
    }

    static func signedKg(_ value: Double) -> String {
        value >= 0 ? "+" + kg(value) : "−" + kg(-value)
    }
}
