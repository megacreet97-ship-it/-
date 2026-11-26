import Foundation

enum Muscle: String, CaseIterable, Identifiable {
    case chest, lats, traps, lowerBack, frontDelts, sideDelts, rearDelts, biceps, triceps
    case forearms, abs, obliques, quads, hamstrings, glutes, adductors, calves, cardio

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chest: "Грудь"
        case .lats: "Широчайшие"
        case .traps: "Трапеции, верх спины"
        case .lowerBack: "Поясница"
        case .frontDelts: "Передние дельты"
        case .sideDelts: "Средние дельты"
        case .rearDelts: "Задние дельты"
        case .biceps: "Бицепс"
        case .triceps: "Трицепс"
        case .forearms: "Предплечья, хват"
        case .abs: "Пресс"
        case .obliques: "Косые мышцы"
        case .quads: "Квадрицепс"
        case .hamstrings: "Бицепс бедра"
        case .glutes: "Ягодицы"
        case .adductors: "Приводящие бедра"
        case .calves: "Икры"
        case .cardio: "Выносливость"
        }
    }

    static let groups: [(title: String, muscles: [Muscle])] = [
        ("Спина и грудь", [.chest, .lats, .traps, .lowerBack]),
        ("Плечи", [.frontDelts, .sideDelts, .rearDelts]),
        ("Руки", [.biceps, .triceps, .forearms]),
        ("Кор", [.abs, .obliques]),
        ("Ноги", [.quads, .hamstrings, .glutes, .adductors, .calves]),
    ]

    /// Muscles worth a suggestion when they get too little work; small helpers are left out.
    static let key: [Muscle] = [.chest, .lats, .sideDelts, .rearDelts, .biceps, .triceps, .abs, .quads, .hamstrings, .glutes, .calves]
}

enum ExerciseKind: String {
    case compound, isolation, `static`, cardio, stretch

    var title: String {
        switch self {
        case .compound: "Базовое"
        case .isolation: "Изолирующее"
        case .static: "Статика"
        case .cardio: "Кардио"
        case .stretch: "Растяжка"
        }
    }
}

struct ExerciseInfo {
    let primary: [Muscle]
    let secondary: [Muscle]
    let kind: ExerciseKind
    let equipment: String
    /// 1–3; 0 for the user's own exercises.
    let level: Int
    /// 1–5, expert estimate of how well the exercise loads its primary muscles; 0 when unknown.
    let rating: Int
    let tip: String
    /// Stem of the bundled start/end technique photos (`<photo>-0.jpg`, `<photo>-1.jpg`).
    var photo: String? = nil

    var levelTitle: String {
        switch level {
        case 1: "Новичок"
        case 2: "Средний"
        case 3: "Продвинутый"
        default: ""
        }
    }

    private static let categoryFallback: [String: (primary: [Muscle], secondary: [Muscle], kind: ExerciseKind)] = [
        "Турник": ([.lats, .biceps], [.forearms], .compound),
        "Брусья": ([.chest, .triceps], [.frontDelts], .compound),
        "Грудь": ([.chest], [.triceps, .frontDelts], .compound),
        "Спина": ([.lats], [.traps, .biceps], .compound),
        "Плечи": ([.sideDelts, .frontDelts], [.triceps], .compound),
        "Бицепс": ([.biceps], [.forearms], .isolation),
        "Трицепс": ([.triceps], [], .isolation),
        "Предплечья и хват": ([.forearms], [], .isolation),
        "Ноги": ([.quads, .glutes], [.hamstrings], .compound),
        "Ягодицы": ([.glutes], [.hamstrings], .compound),
        "Икры": ([.calves], [], .isolation),
        "Пресс и кор": ([.abs], [.obliques], .isolation),
        "Кардио": ([.cardio], [], .cardio),
        "Растяжка и мобильность": ([.lowerBack], [], .stretch),
    ]

    /// Library description, or a rough one built from the category for the user's own exercises.
    static func lookup(_ name: String, category: String? = nil, lift: Lift? = nil) -> ExerciseInfo? {
        if let known = library[name] { return known }
        let key: String?
        switch lift {
        case .pullUp: key = "Турник"
        case .dip: key = "Брусья"
        case nil: key = category
        }
        guard let key, let fallback = categoryFallback[key] else { return nil }
        return ExerciseInfo(primary: fallback.primary, secondary: fallback.secondary, kind: fallback.kind,
                            equipment: "", level: 0, rating: 0, tip: "")
    }
}

enum VolumeZone: CaseIterable {
    case none, low, maintain, grow, high

    /// Common hypertrophy guidance: about 10–20 hard sets per muscle per week.
    init(sets: Double) {
        if sets <= 0 { self = .none } else if sets < 4 { self = .low } else if sets < 10 { self = .maintain } else if sets <= 20 { self = .grow } else { self = .high }
    }

    var title: String {
        switch self {
        case .none: "Нет нагрузки"
        case .low: "Мало"
        case .maintain: "Поддержка"
        case .grow: "Рост"
        case .high: "Много"
        }
    }

    var range: String {
        switch self {
        case .none: "0"
        case .low: "<4"
        case .maintain: "4–9"
        case .grow: "10–20"
        case .high: ">20"
        }
    }
}

struct ExerciseProgress: Identifiable {
    let name: String
    let before: Double
    let now: Double
    let weighted: Bool
    var change: Double { now / before - 1 }
    var id: String { name }
}

enum MuscleAnalytics {
    /// Hard sets per muscle: a primary muscle gets the whole set, a secondary one half. Cardio counts sessions.
    static func sets(_ items: [LogItem], lookup: (String) -> ExerciseInfo?) -> [Muscle: Double] {
        var result: [Muscle: Double] = [:]
        for item in items {
            guard let info = lookup(item.exercise), info.kind != .stretch else { continue }
            if info.kind == .cardio {
                result[.cardio, default: 0] += Double(item.sets)
                continue
            }
            for muscle in info.primary { result[muscle, default: 0] += Double(item.sets) }
            for muscle in info.secondary { result[muscle, default: 0] += Double(item.sets) / 2 }
        }
        return result
    }

    /// Best exercises for a muscle: where it is a primary mover, highest rating first, then more focused, then easier.
    static func best(for muscle: Muscle, limit: Int = .max) -> [(name: String, info: ExerciseInfo)] {
        let sorted = ExerciseInfo.library
            .filter { $0.value.primary.contains(muscle) }
            .sorted { lhs, rhs in
                if lhs.value.rating != rhs.value.rating { return lhs.value.rating > rhs.value.rating }
                if lhs.value.primary.count != rhs.value.primary.count { return lhs.value.primary.count < rhs.value.primary.count }
                if lhs.value.level != rhs.value.level { return lhs.value.level < rhs.value.level }
                return lhs.key < rhs.key
            }
        return sorted.prefix(limit).map { (name: $0.key, info: $0.value) }
    }

    /// Estimated 1RM with added weight, otherwise the best set's reps.
    static func score(_ item: LogItem) -> Double {
        let best = item.setReps?.max() ?? item.reps
        return item.addedWeight > 0 ? item.addedWeight * (1 + Double(min(best, 12)) / 30) : Double(best)
    }

    /// Compares the best session of the last 4 weeks with the 4 weeks before them.
    static func progress(_ items: [LogItem], now: Date = .now, calendar: Calendar = .current) -> [ExerciseProgress] {
        let today = calendar.startOfDay(for: now)
        guard let split = calendar.date(byAdding: .day, value: -27, to: today),
              let from = calendar.date(byAdding: .day, value: -28, to: split) else { return [] }
        var rows: [String: (before: Double, now: Double, weighted: Bool)] = [:]
        for item in items where item.date >= from {
            var row = rows[item.exercise] ?? (0, 0, false)
            let value = score(item)
            if item.date >= split { row.now = max(row.now, value) } else { row.before = max(row.before, value) }
            row.weighted = row.weighted || item.addedWeight > 0
            rows[item.exercise] = row
        }
        return rows
            .filter { $0.value.before > 0 && $0.value.now > 0 }
            .map { ExerciseProgress(name: $0.key, before: $0.value.before, now: $0.value.now, weighted: $0.value.weighted) }
            .sorted { $0.change != $1.change ? $0.change > $1.change : $0.name < $1.name }
    }

    /// Number of sessions since `since` that beat every earlier session of the same exercise.
    static func personalRecords(_ items: [LogItem], since: Date) -> Int {
        var best: [String: Double] = [:]
        var count = 0
        for item in items.sorted(by: { $0.date < $1.date }) {
            let value = score(item)
            if let previous = best[item.exercise] {
                if value > previous + 1e-9 && item.date >= since { count += 1 }
                if value > previous { best[item.exercise] = value }
            } else {
                best[item.exercise] = value
            }
        }
        return count
    }
}
