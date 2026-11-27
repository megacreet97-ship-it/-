import Foundation
@testable import StreetLogLogic
import XCTest

final class BodyAndMusclesTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_795_000_000)
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Moscow")!
        return calendar
    }

    private func item(_ daysAgo: Double, _ name: String, sets: Int, reps: Int, weight: Double = 0) -> LogItem {
        LogItem(date: now.addingTimeInterval(-daysAgo * 86_400), exercise: name, reps: reps, sets: sets, addedWeight: weight)
    }

    func testLibraryDescribesEveryExercise() {
        XCTAssertEqual(ExerciseInfo.library.count, ExerciseLibrary.all.count)
        XCTAssertEqual(ExerciseInfo.lookup("Выпады с гантелями")?.primary, [.quads, .glutes])
        XCTAssertEqual(ExerciseInfo.lookup("Мой жим", category: "Грудь")?.primary, [.chest])
        XCTAssertEqual(ExerciseInfo.lookup("Что-то", lift: .pullUp)?.primary, [.lats, .biceps])
        XCTAssertNil(ExerciseInfo.lookup("Неизвестное"))
    }

    func testMuscleSets() {
        let sets = MuscleAnalytics.sets([item(1, "Отжимания на брусьях", sets: 4, reps: 10), item(2, "Бег (мин)", sets: 1, reps: 20)]) { ExerciseInfo.lookup($0) }
        XCTAssertEqual(sets[.chest], 4)
        XCTAssertEqual(sets[.frontDelts], 2)
        XCTAssertEqual(sets[.cardio], 1)
        XCTAssertEqual(VolumeZone(sets: 4), .maintain)
        XCTAssertEqual(VolumeZone(sets: 12), .grow)
        XCTAssertEqual(MuscleAnalytics.best(for: .glutes, limit: 1).first?.name, "Ягодичный мост со штангой")
    }

    func testProgressAndRecords() {
        let items = [item(40, "Подтягивания", sets: 3, reps: 8), item(10, "Подтягивания", sets: 3, reps: 10),
                     item(45, "Жим лёжа", sets: 3, reps: 5, weight: 50), item(5, "Жим лёжа", sets: 3, reps: 5, weight: 55)]
        let progress = MuscleAnalytics.progress(items, now: now, calendar: calendar)
        XCTAssertEqual(progress.map(\.name), ["Подтягивания", "Жим лёжа"])
        XCTAssertEqual(progress[0].change, 0.25, accuracy: 1e-9)
        XCTAssertEqual(MuscleAnalytics.personalRecords(items, since: now.addingTimeInterval(-30 * 86_400)), 2)
    }

    func testBodyGoals() {
        let points = (0..<14).map { DatedValue(date: now.addingTimeInterval(Double(-28 + 2 * $0) * 86_400), value: 70 - 0.1 * Double(2 * $0)) }
        XCTAssertEqual(BodyMath.weeklyRate(points, now: now, calendar: calendar) ?? 0, -0.7, accuracy: 1e-6)
        XCTAssertNil(BodyMath.weeklyRate(Array(points.suffix(2)), now: now, calendar: calendar))
        XCTAssertEqual(BodyMath.verdict(goal: .fatLoss, weight: 70, weightPerWeek: -0.5, waistPerWeek: nil).tone, .good)
        XCTAssertEqual(BodyMath.verdict(goal: .muscle, weight: 70, weightPerWeek: 0.6, waistPerWeek: nil).tone, .warn)
        XCTAssertEqual(BodyMath.verdict(goal: .recomp, weight: 60, weightPerWeek: 0.05, waistPerWeek: -0.3).title, "Идёт рекомпозиция")
        XCTAssertEqual(BodyMath.proteinRange(weight: 60), 95...130)
        XCTAssertEqual(BodyMath.reachDate(current: 70, target: 68, perWeek: -0.5, now: now), now.addingTimeInterval(28 * 86_400))
        XCTAssertNil(BodyMath.reachDate(current: 70, target: 68, perWeek: 0.5, now: now))
        XCTAssertEqual(BodyMath.targetProgress(start: 70, current: 68, target: 65), 0.4, accuracy: 1e-9)
    }
}
