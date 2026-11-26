import Foundation
@testable import StreetLogLogic
import XCTest

final class StreetliftingMathTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Moscow")!
        calendar.firstWeekday = 2
        return calendar
    }

    private func day(_ offset: Int, from base: Date = Date(timeIntervalSince1970: 1_767_225_600)) -> Date {
        calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: base))!
    }

    func testOneRepMaxUsesSystemWeight() {
        XCTAssertEqual(OneRepMax.estimatedAddedWeight(added: 40, bodyweight: 80, reps: 1), 40)
        let estimate = OneRepMax.estimatedAddedWeight(added: 20, bodyweight: 80, reps: 5)!
        // Epley: 100 * (1 + 5/30) = 116.67, Brzycki: 100 * 36/32 = 112.5 → avg 114.58 − 80
        XCTAssertEqual(estimate, 34.58, accuracy: 0.01)
        XCTAssertNil(OneRepMax.estimatedAddedWeight(added: 20, bodyweight: 80, reps: 20))
        XCTAssertNil(OneRepMax.estimatedAddedWeight(added: 20, bodyweight: 0, reps: 3))
    }

    func testLinearTrendAndReachDate() {
        let points = (0..<5).map { DatedValue(date: day($0 * 7), value: 40 + Double($0) * 1.25) }
        let trend = LinearTrend(points: points)!
        XCTAssertEqual(trend.slopePerWeek, 1.25, accuracy: 1e-9)
        let reach = trend.date(reaching: 50)!
        XCTAssertEqual(reach.timeIntervalSince(day(56)) / 86_400, 0, accuracy: 1e-6)
        XCTAssertNil(LinearTrend(points: [points[0]]))
        XCTAssertNil(LinearTrend(points: [DatedValue(date: day(0), value: 1), DatedValue(date: day(0), value: 2)]))
    }

    func testForecastStatuses() {
        let points = (0..<5).map { DatedValue(date: day($0 * 7), value: 40 + Double($0)) }
        let today = day(28)
        let onTrack = LiftForecast.make(current: 44, target: 48, points: points, today: today, competition: day(70))
        XCTAssertEqual(onTrack.status, .onTrack)
        XCTAssertEqual(onTrack.neededPerWeek!, 4.0 / 6.0, accuracy: 1e-9)

        let behind = LiftForecast.make(current: 44, target: 60, points: points, today: today, competition: day(42))
        XCTAssertEqual(behind.status, .behind)

        XCTAssertEqual(LiftForecast.make(current: 50, target: 48, points: points, today: today, competition: nil).status, .reached)
        XCTAssertEqual(LiftForecast.make(current: 40, target: 48, points: [], today: today, competition: nil).status, .notEnoughData)
        XCTAssertEqual(LiftForecast.make(current: 44, target: 48, points: points, today: today, competition: nil).status, .projected)
    }

    func testAttemptPlanIsIncreasingAndRounded() {
        XCTAssertEqual(AttemptPlanner.plan(currentMax: 50), [46.25, 48.75, 50])
        let small = AttemptPlanner.plan(currentMax: 5)
        XCTAssertEqual(small, [5, 6.25, 7.5])
        XCTAssertTrue(AttemptPlanner.plan(currentMax: 0).isEmpty)
    }

    func testPrepPhase() {
        let today = day(0)
        XCTAssertEqual(PrepPhase.make(today: today, competition: nil, calendar: calendar), .noDate)
        XCTAssertEqual(PrepPhase.make(today: today, competition: day(0), calendar: calendar), .competitionDay)
        XCTAssertEqual(PrepPhase.make(today: today, competition: day(7), calendar: calendar), .taper(days: 7))
        XCTAssertEqual(PrepPhase.make(today: today, competition: day(20), calendar: calendar), .peaking(days: 20))
        XCTAssertEqual(PrepPhase.make(today: today, competition: day(42), calendar: calendar), .strength(weeks: 6))
        XCTAssertEqual(PrepPhase.make(today: today, competition: day(84), calendar: calendar), .base(weeks: 12))
        XCTAssertEqual(PrepPhase.make(today: today, competition: day(200), calendar: calendar), .offSeason(weeks: 28))
        XCTAssertEqual(PrepPhase.make(today: today, competition: day(-1), calendar: calendar), .past)
    }

    func testDiaryAnalytics() {
        let items = [
            LogItem(date: day(0), exercise: "A", reps: 10, sets: 3, addedWeight: 0),
            LogItem(date: day(1), exercise: "A", reps: 8, sets: 4, addedWeight: 0),
            LogItem(date: day(1), exercise: "B", reps: 5, sets: 5, addedWeight: 20),
            LogItem(date: day(2), exercise: "B", reps: 3, sets: 5, addedWeight: 25),
            LogItem(date: day(5), exercise: "A", reps: 12, sets: 2, addedWeight: 0),
        ]
        XCTAssertEqual(DiaryAnalytics.totalReps(items), 30 + 32 + 25 + 15 + 24)
        let days = DiaryAnalytics.trainingDays(items, calendar: calendar)
        XCTAssertEqual(days.count, 4)
        XCTAssertEqual(DiaryAnalytics.longestStreak(days: days, calendar: calendar), 3)
        XCTAssertEqual(DiaryAnalytics.currentStreak(days: days, today: day(2), calendar: calendar), 3)
        XCTAssertEqual(DiaryAnalytics.currentStreak(days: days, today: day(3), calendar: calendar), 3)
        XCTAssertEqual(DiaryAnalytics.currentStreak(days: days, today: day(4), calendar: calendar), 0)

        let totals = DiaryAnalytics.exerciseTotals(items, calendar: calendar)
        XCTAssertEqual(totals.first?.name, "A")
        XCTAssertEqual(totals.first?.totalReps, 86)
        XCTAssertEqual(totals.last?.maxWeight, 25)

        let progressB = DiaryAnalytics.dailyProgress(items, exercise: "B", calendar: calendar)
        XCTAssertEqual(progressB.map(\.value), [20, 25])
        let progressA = DiaryAnalytics.dailyProgress(items, exercise: "A", calendar: calendar)
        XCTAssertEqual(progressA.map(\.value), [30, 32, 24])

        let weekly = DiaryAnalytics.weeklyReps(items, calendar: calendar)
        XCTAssertEqual(weekly.reduce(0) { $0 + $1.value }, 126)
    }

    func testFormat() {
        XCTAssertEqual(Format.kg(50), "50 кг")
        XCTAssertEqual(Format.kg(47.5), "47,5 кг")
        XCTAssertEqual(Format.kg(46.25), "46,25 кг")
        XCTAssertEqual(Format.signedKg(-2.5), "−2,5 кг")
    }

    func testStandardsLookupAndSplit() {
        let isf675 = Standards.lookup(federation: .isf, limit: 67.5)!
        XCTAssertEqual(isf675.norms(for: .ms)?.total, 152.5)
        XCTAssertEqual(Standards.lookup(federation: .isf, limit: 75)?.norms(for: .ms)?.total, 165)
        XCTAssertEqual(Standards.lookup(federation: .wsf, limit: 67.5)?.norms(for: .ms)?.total, 140)
        XCTAssertEqual(Standards.lookup(federation: .wsf, limit: 75)?.norms(for: .ms)?.total, 152.5)
        XCTAssertEqual(Standards.classes(for: .isf).map(\.limit), [67.5, 75])

        for standard in Standards.all {
            let ranks = SportRank.allCases.compactMap { standard.norms(for: $0) }
            XCTAssertEqual(ranks.count, 3)
            XCTAssertEqual(ranks.map(\.total), ranks.map(\.total).sorted(), "ranks must increase in \(standard.id)")
            let split = Standards.split(standard.norms(for: .ms)!)
            XCTAssertEqual(split.pullUp + split.dip, standard.norms(for: .ms)!.total, accuracy: 1e-9)
            XCTAssertEqual(split.pullUp.truncatingRemainder(dividingBy: 1.25), 0, accuracy: 1e-9)
        }
        XCTAssertEqual(Standards.split(isf675.norms(for: .ms)!).pullUp, 61.25)

        XCTAssertEqual(isf675.achievedRank(total: 134), nil)
        XCTAssertEqual(isf675.achievedRank(total: 135), .kms)
        XCTAssertEqual(isf675.achievedRank(total: 160), .ms)
        XCTAssertEqual(isf675.achievedRank(total: 200), .msmk)

        XCTAssertEqual(Standards.classFor(bodyweight: 67.5, federation: .isf)?.limit, 67.5)
        XCTAssertEqual(Standards.classFor(bodyweight: 67.6, federation: .isf)?.limit, 75)
        XCTAssertNil(Standards.classFor(bodyweight: 80, federation: .isf))
        XCTAssertEqual(Format.number(67.5), "67,5")
    }

    func testPerSetReps() {
        let item = LogItem(date: .now, exercise: "x", reps: 8, sets: 4, addedWeight: 10, setReps: [8, 8, 8, 3])
        XCTAssertEqual(item.totalReps, 27)
        XCTAssertEqual(item.tonnage, 270)
        XCTAssertEqual(SetsFormat.label(sets: 4, reps: 8, setReps: [8, 8, 8, 3]), "8, 8, 8, 3")
        XCTAssertEqual(SetsFormat.label(sets: 4, reps: 8, setReps: nil), "4 × 8")
        let equal = SetsFormat.normalize([8, 8, 8])
        XCTAssertEqual(equal.sets, 3)
        XCTAssertEqual(equal.reps, 8)
        XCTAssertNil(equal.setReps)
        let mixed = SetsFormat.normalize([8, 8, 8, 3])
        XCTAssertEqual(mixed.sets, 4)
        XCTAssertEqual(mixed.reps, 8)
        XCTAssertEqual(mixed.setReps, [8, 8, 8, 3])
    }
}
