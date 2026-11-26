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
    /// Comma-separated reps of each set when they differ; empty when all sets are equal.
    var setRepsRaw: String = ""

    init(date: Date, exerciseName: String, lift: Lift?, reps: Int, sets: Int, addedWeight: Double = 0, note: String = "",
         setReps: [Int]? = nil) {
        self.date = date
        self.exerciseName = exerciseName
        self.liftRaw = lift?.rawValue
        self.reps = reps
        self.sets = sets
        self.addedWeight = addedWeight
        self.note = note
        self.setReps = setReps
    }

    var setReps: [Int]? {
        get {
            let list = setRepsRaw.split(separator: ",").compactMap { Int($0) }
            return list.isEmpty ? nil : list
        }
        set { setRepsRaw = newValue?.map(String.init).joined(separator: ",") ?? "" }
    }

    var setsLabel: String { SetsFormat.label(sets: sets, reps: reps, setReps: setReps) }

    var lift: Lift? {
        get { liftRaw.flatMap(Lift.init(rawValue:)) }
        set { liftRaw = newValue?.rawValue }
    }

    var logItem: LogItem {
        LogItem(date: date, exercise: exerciseName, reps: reps, sets: sets, addedWeight: addedWeight, setReps: setReps)
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
    var federationRaw: String = Federation.isf.rawValue
    /// Upper limit of the chosen class from `Standards`; 0 means custom targets entered by hand.
    var weightClassLimit: Double = 0
    var goalRankRaw: String = SportRank.ms.rawValue
    /// Raw value of `Goal`; empty until the user picks one (see `effectiveGoal`).
    var goalRaw: String = ""
    var targetWeight: Double = 0
    var targetWaist: Double = 0
    var weeklyWorkouts: Int = 3

    init(name: String = "",
         bodyweight: Double = 67,
         weightClass: String = "до 67,5 кг",
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

    var federation: Federation {
        get { Federation(rawValue: federationRaw) ?? .isf }
        set { federationRaw = newValue.rawValue }
    }

    var goalRank: SportRank {
        get { SportRank(rawValue: goalRankRaw) ?? .ms }
        set { goalRankRaw = newValue.rawValue }
    }

    var goal: Goal? {
        get { Goal(rawValue: goalRaw) }
        set { goalRaw = newValue?.rawValue ?? "" }
    }

    /// Users from before goals existed and anyone with streetlifting data keep the МС screen.
    func effectiveGoal(hasStreetliftingData: Bool) -> Goal? {
        goal ?? (hasStreetliftingData ? .ms : nil)
    }

    var standard: WeightClassStandard? {
        Standards.lookup(federation: federation, limit: weightClassLimit)
    }

    var goalTotal: Double {
        targetTotal > 0 ? targetTotal : targetPullUp + targetDip
    }

    /// Copies the norms of the chosen federation/class/rank into the targets.
    func applyStandard() {
        guard let standard, let norms = standard.norms(for: goalRank) else { return }
        let split = Standards.split(norms)
        weightClass = standard.title
        targetTotal = norms.total
        targetPullUp = split.pullUp
        targetDip = split.dip
    }
}

/// Body weight and optional waist / body-fat measurements for the body-composition goals.
@Model
final class BodyMeasurement {
    var date: Date
    var weight: Double
    /// Centimetres; 0 when not measured.
    var waist: Double = 0
    /// Percent; 0 when not measured.
    var bodyFat: Double = 0

    init(date: Date, weight: Double, waist: Double = 0, bodyFat: Double = 0) {
        self.date = date
        self.weight = weight
        self.waist = waist
        self.bodyFat = bodyFat
    }
}

enum SeedData {
    private static let libraryVersionKey = "exerciseLibraryVersion"

    static func seedIfNeeded(_ context: ModelContext) {
        mergeLibraryIfNeeded(context)
        let profileCount = (try? context.fetchCount(FetchDescriptor<AthleteProfile>())) ?? 0
        if profileCount == 0 {
            let profile = AthleteProfile()
            profile.weightClassLimit = 67.5
            profile.applyStandard()
            context.insert(profile)
        }
        try? context.save()
    }

    /// Adds library exercises the user doesn't have yet and moves known ones into the current categories.
    static func mergeLibraryIfNeeded(_ context: ModelContext) {
        let defaults = UserDefaults.standard
        guard defaults.integer(forKey: libraryVersionKey) < ExerciseLibrary.version else { return }
        let existing = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        var known = Set<String>()
        let library = Dictionary(ExerciseLibrary.all.map { ($0.name.lowercased(), $0.category) }, uniquingKeysWith: { first, _ in first })
        for exercise in existing {
            let key = exercise.name.lowercased()
            known.insert(key)
            if let category = library[key] { exercise.category = category }
        }
        for item in ExerciseLibrary.all where !known.contains(item.name.lowercased()) {
            context.insert(Exercise(name: item.name, category: item.category, lift: item.lift))
        }
        defaults.set(ExerciseLibrary.version, forKey: libraryVersionKey)
    }
}
