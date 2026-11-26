#if DEBUG
import Foundation
import SwiftData

/// Sample data for simulator screenshots. Enabled with the `-seedDemo YES` launch argument (Debug builds only).
enum DemoData {
    static func seedIfRequested(_ context: ModelContext) {
        guard UserDefaults.standard.bool(forKey: "seedDemo"),
              ((try? context.fetchCount(FetchDescriptor<WorkoutEntry>())) ?? 0) == 0 else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        func day(_ offset: Int, hour: Int = 18) -> Date {
            let date = calendar.date(byAdding: .day, value: offset, to: today) ?? today
            return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
        }

        if let profile = try? context.fetch(FetchDescriptor<AthleteProfile>()).first {
            profile.name = "Демо"
            profile.bodyweight = 78
            profile.weightClass = "до 80 кг"
            profile.targetPullUp = 45
            profile.targetDip = 65
            profile.competitionDate = calendar.date(byAdding: .day, value: 45, to: today)
            profile.competitionName = "Кубок города"
        }

        for week in 0..<12 {
            let offset = -84 + week * 7
            context.insert(MaxAttempt(date: day(offset + 5), lift: .pullUp,
                                      addedWeight: AttemptPlanner.round(30 + Double(week) * 0.9 + (week % 3 == 0 ? -1 : 0)), bodyweight: 78))
            context.insert(MaxAttempt(date: day(offset + 5), lift: .dip,
                                      addedWeight: AttemptPlanner.round(45 + Double(week) * 1.1 + (week % 4 == 1 ? -1.25 : 0)), bodyweight: 78.5))
        }

        for offset in stride(from: -56, through: 0, by: 1) {
            let weekday = calendar.component(.weekday, from: day(offset))
            guard [2, 4, 6].contains(weekday) else { continue }
            let progress = Double(offset + 56) / 56
            let date = day(offset)
            context.insert(WorkoutEntry(date: date, exerciseName: "Подтягивания с отягощением", lift: .pullUp,
                                        reps: 5, sets: 4, addedWeight: AttemptPlanner.round(20 + 6 * progress)))
            context.insert(WorkoutEntry(date: date.addingTimeInterval(900), exerciseName: "Отжимания на брусьях с отягощением", lift: .dip,
                                        reps: 5, sets: 4, addedWeight: AttemptPlanner.round(32 + 8 * progress)))
            context.insert(WorkoutEntry(date: date.addingTimeInterval(1800), exerciseName: weekday == 4 ? "Подтягивания широким хватом" : "Отжимания от пола",
                                        lift: nil, reps: weekday == 4 ? 10 : 25, sets: 3))
            context.insert(WorkoutEntry(date: date.addingTimeInterval(2700), exerciseName: "Подъём ног в висе",
                                        lift: nil, reps: 12, sets: 3))
        }
        try? context.save()
    }
}
#endif
