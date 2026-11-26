#if DEBUG
import Foundation
import SwiftData
import SwiftUI

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
            profile.bodyweight = 70.5
            profile.federation = .isf
            profile.weightClassLimit = 67.5
            profile.goalRank = .ms
            profile.applyStandard()
            profile.competitionDate = calendar.date(byAdding: .day, value: 45, to: today)
            profile.competitionName = "Кубок города"
        }

        for week in 0..<12 {
            let offset = -84 + week * 7
            context.insert(MaxAttempt(date: day(offset + 5), lift: .pullUp,
                                      addedWeight: AttemptPlanner.round(50 + Double(week) * 0.9 + (week % 3 == 0 ? -1 : 0)), bodyweight: 70.5))
            context.insert(MaxAttempt(date: day(offset + 5), lift: .dip,
                                      addedWeight: AttemptPlanner.round(72 + Double(week) * 1.2 + (week % 4 == 1 ? -1.25 : 0)), bodyweight: 70.5))
        }

        for offset in stride(from: -56, through: 0, by: 1) {
            let weekday = calendar.component(.weekday, from: day(offset))
            guard [2, 4, 6].contains(weekday) || offset == 0 else { continue }
            let progress = Double(offset + 56) / 56
            let date = day(offset)
            context.insert(WorkoutEntry(date: date, exerciseName: "Подтягивания с отягощением", lift: .pullUp,
                                        reps: 5, sets: 4, addedWeight: AttemptPlanner.round(35 + 6 * progress)))
            context.insert(WorkoutEntry(date: date.addingTimeInterval(900), exerciseName: "Отжимания на брусьях с отягощением", lift: .dip,
                                        reps: 5, sets: 4, addedWeight: AttemptPlanner.round(50 + 8 * progress)))
            context.insert(WorkoutEntry(date: date.addingTimeInterval(1800), exerciseName: weekday == 4 ? "Подтягивания широким хватом" : "Отжимания от пола",
                                        lift: nil, reps: weekday == 4 ? 10 : 25, sets: 3))
            context.insert(WorkoutEntry(date: date.addingTimeInterval(2700), exerciseName: "Подъём ног в висе",
                                        lift: nil, reps: 12, sets: 3))
        }
        try? context.save()
    }
}

struct DemoScreen: Identifiable {
    let id: String
}

/// Opens a specific screen on launch (`-demoScreen quicklog|standards`) for simulator screenshots.
struct DemoScreenView: View {
    let name: String
    @Query(sort: \MaxAttempt.date) private var attempts: [MaxAttempt]

    private func best(_ lift: Lift) -> Double {
        attempts.filter { $0.lift == lift }.map(\.addedWeight).max() ?? 0
    }

    var body: some View {
        switch name {
        case "standards":
            NavigationStack {
                StandardsView(initialFederation: .isf, total: best(.pullUp) + best(.dip), pullUp: best(.pullUp), dip: best(.dip))
            }
        default:
            QuickLogSheet(draft: LogDraft(date: .now, exerciseName: "Подтягивания с отягощением"))
        }
    }
}
#endif
