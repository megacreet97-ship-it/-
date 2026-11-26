import Foundation
import SwiftData

@Model
final class Exercise {
    var name: String
    var category: String
    /// Raw value of `Lift` when the exercise is a competitive streetlifting movement.
    var liftRaw: String?
    var createdAt: Date

    init(name: String, category: String, lift: Lift? = nil) {
        self.name = name
        self.category = category
        self.liftRaw = lift?.rawValue
        self.createdAt = .now
    }

    var lift: Lift? {
        get { liftRaw.flatMap(Lift.init(rawValue:)) }
        set { liftRaw = newValue?.rawValue }
    }
}

@Model
final class WorkoutEntry {
    var date: Date
    var exerciseName: String
    var liftRaw: String?
    var reps: Int
    var sets: Int
    var addedWeight: Double
    var note: String

    init(date: Date, exerciseName: String, lift: Lift?, reps: Int, sets: Int, addedWeight: Double = 0, note: String = "") {
        self.date = date
        self.exerciseName = exerciseName
        self.liftRaw = lift?.rawValue
        self.reps = reps
        self.sets = sets
        self.addedWeight = addedWeight
        self.note = note
    }

    var lift: Lift? {
        get { liftRaw.flatMap(Lift.init(rawValue:)) }
        set { liftRaw = newValue?.rawValue }
    }

    var logItem: LogItem {
        LogItem(date: date, exercise: exerciseName, reps: reps, sets: sets, addedWeight: addedWeight)
    }
}

/// A one-rep max result (training test or competition attempt) in added weight.
@Model
final class MaxAttempt {
    var date: Date
    var liftRaw: String
    var addedWeight: Double
    var bodyweight: Double
    var isCompetition: Bool
    var note: String

    init(date: Date, lift: Lift, addedWeight: Double, bodyweight: Double, isCompetition: Bool = false, note: String = "") {
        self.date = date
        self.liftRaw = lift.rawValue
        self.addedWeight = addedWeight
        self.bodyweight = bodyweight
        self.isCompetition = isCompetition
        self.note = note
    }

    var lift: Lift {
        get { Lift(rawValue: liftRaw) ?? .pullUp }
        set { liftRaw = newValue.rawValue }
    }
}

@Model
final class AthleteProfile {
    var name: String
    var bodyweight: Double
    var weightClass: String
    var targetPullUp: Double
    var targetDip: Double
    var targetTotal: Double
    var competitionDate: Date?
    var competitionName: String

    init(name: String = "",
         bodyweight: Double = 80,
         weightClass: String = "до 80 кг",
         targetPullUp: Double = 0,
         targetDip: Double = 0,
         targetTotal: Double = 0,
         competitionDate: Date? = nil,
         competitionName: String = "") {
        self.name = name
        self.bodyweight = bodyweight
        self.weightClass = weightClass
        self.targetPullUp = targetPullUp
        self.targetDip = targetDip
        self.targetTotal = targetTotal
        self.competitionDate = competitionDate
        self.competitionName = competitionName
    }

    func target(for lift: Lift) -> Double {
        switch lift {
        case .pullUp: targetPullUp
        case .dip: targetDip
        }
    }

    var hasTargets: Bool { targetTotal > 0 || targetPullUp > 0 || targetDip > 0 }
}

enum SeedData {
    static let exercises: [(String, String, Lift?)] = [
        ("Подтягивания с отягощением", "Стритлифтинг", .pullUp),
        ("Отжимания на брусьях с отягощением", "Стритлифтинг", .dip),
        ("Подтягивания", "Турник", nil),
        ("Подтягивания широким хватом", "Турник", nil),
        ("Подтягивания обратным хватом", "Турник", nil),
        ("Негативные подтягивания", "Турник", nil),
        ("Отжимания на брусьях", "Брусья", nil),
        ("Отжимания от пола", "Брусья", nil),
        ("Тяга штанги в наклоне", "Подсобка", nil),
        ("Жим лёжа", "Подсобка", nil),
        ("Французский жим", "Подсобка", nil),
        ("Сгибания на бицепс", "Подсобка", nil),
        ("Подъём ног в висе", "Кор", nil),
        ("Планка (сек)", "Кор", nil),
    ]

    static func seedIfNeeded(_ context: ModelContext) {
        let exerciseCount = (try? context.fetchCount(FetchDescriptor<Exercise>())) ?? 0
        if exerciseCount == 0 {
            for (name, category, lift) in exercises {
                context.insert(Exercise(name: name, category: category, lift: lift))
            }
        }
        let profileCount = (try? context.fetchCount(FetchDescriptor<AthleteProfile>())) ?? 0
        if profileCount == 0 {
            context.insert(AthleteProfile())
        }
        try? context.save()
    }
}
