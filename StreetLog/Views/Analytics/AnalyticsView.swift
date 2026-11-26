import Charts
import SwiftData
import SwiftUI

enum AnalyticsPeriod: String, CaseIterable, Identifiable {
    case month = "4 нед"
    case quarter = "12 нед"
    case year = "Год"
    case all = "Всё"

    var id: String { rawValue }

    func startDate(calendar: Calendar = .current, now: Date = .now) -> Date? {
        let today = calendar.startOfDay(for: now)
        switch self {
        case .month: return calendar.date(byAdding: .weekOfYear, value: -4, to: today)
        case .quarter: return calendar.date(byAdding: .weekOfYear, value: -12, to: today)
        case .year: return calendar.date(byAdding: .year, value: -1, to: today)
        case .all: return nil
        }
    }
}

struct AnalyticsView: View {
    @Query(sort: \WorkoutEntry.date) private var entries: [WorkoutEntry]
    @State private var period: AnalyticsPeriod = .quarter

    private let calendar = Calendar.current

    private var periodEntries: [WorkoutEntry] {
        guard let start = period.startDate(calendar: calendar) else { return entries }
        return entries.filter { $0.date >= start }
    }

    private var items: [LogItem] { periodEntries.map(\.logItem) }

    private var weeksInPeriod: Double {
        let start = period.startDate(calendar: calendar) ?? entries.first?.date ?? .now
        return max(Date.now.timeIntervalSince(start) / (7 * 86_400), 1)
    }

    private var liftTonnageByWeek: [DatedValue] {
        var buckets: [Date: Double] = [:]
        for entry in periodEntries where entry.lift != nil {
            buckets[DiaryAnalytics.weekStart(for: entry.date, calendar: calendar), default: 0] += entry.logItem.tonnage
        }
        return buckets.map { DatedValue(date: $0.key, value: $0.value) }.sorted { $0.date < $1.date }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    SegmentedCapsules(items: AnalyticsPeriod.allCases, selection: $period) { $0.rawValue }

                    if items.isEmpty {
                        ContentUnavailableView("Нет данных за период",
                                               systemImage: "chart.bar",
                                               description: Text("Записывайте тренировки во вкладке «Дневник»."))
                            .padding(.top, 40)
                    } else {
                        summaryCard
                        weeklyVolumeCard
                        if !liftTonnageByWeek.isEmpty { tonnageCard }
                        exercisesCard
                    }
                }
                .padding()
            }
            .scrollIndicators(.hidden)
            .background(Color(.systemBackground))
            .navigationTitle("Аналитика")
        }
    }

    private var summaryCard: some View {
        let days = DiaryAnalytics.trainingDays(items, calendar: calendar)
        let allDays = DiaryAnalytics.trainingDays(entries.map(\.logItem), calendar: calendar)
        return Card(title: "Сводка", systemImage: "square.grid.2x2") {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow {
                    StatTile(title: "Тренировок", value: "\(days.count)",
                             caption: String(format: "%.1f в неделю", Double(days.count) / weeksInPeriod).replacingOccurrences(of: ".", with: ","),
                             tint: Theme.orange)
                    StatTile(title: "Серия сейчас", value: "\(DiaryAnalytics.currentStreak(days: allDays, calendar: calendar)) дн.",
                             caption: "лучшая: \(DiaryAnalytics.longestStreak(days: allDays, calendar: calendar)) дн.")
                }
                GridRow {
                    StatTile(title: "Повторений", value: "\(DiaryAnalytics.totalReps(items))")
                    StatTile(title: "Подходов", value: "\(DiaryAnalytics.totalSets(items))")
                }
            }
        }
    }

    private var weeklyVolumeCard: some View {
        Card(title: "Повторения по неделям", systemImage: "chart.bar") {
            Chart(DiaryAnalytics.weeklyReps(items, calendar: calendar)) { point in
                BarMark(x: .value("Неделя", point.date, unit: .weekOfYear),
                        y: .value("Повторения", point.value))
                    .foregroundStyle(Theme.accentGradient)
                    .cornerRadius(6)
            }
            .frame(height: 200)
        }
    }

    private var tonnageCard: some View {
        Card(title: "Тоннаж в соревновательных движениях", systemImage: "scalemass") {
            Chart(liftTonnageByWeek) { point in
                BarMark(x: .value("Неделя", point.date, unit: .weekOfYear),
                        y: .value("кг", point.value))
                    .foregroundStyle(LinearGradient(colors: [Theme.violet, Theme.blue], startPoint: .top, endPoint: .bottom))
                    .cornerRadius(6)
            }
            .frame(height: 180)
            Text("Отягощение × повторения × подходы по подтягиваниям и брусьям с весом. Помогает контролировать нагрузку в блоках подготовки.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var exercisesCard: some View {
        let totals = DiaryAnalytics.exerciseTotals(items, calendar: calendar)
        let maxReps = Double(totals.first?.totalReps ?? 1)
        return Card(title: "Упражнения", systemImage: "list.bullet") {
            ForEach(totals) { total in
                NavigationLink {
                    ExerciseDetailView(exerciseName: total.name)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(total.name).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                            Spacer()
                            Text("\(total.totalReps)").monospacedDigit().foregroundStyle(.secondary)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        }
                        ProgressBar(fraction: Double(total.totalReps) / maxReps, height: 6)
                        Text("\(total.sessions) трен. · \(total.totalSets) подх." + (total.maxWeight > 0 ? " · макс. +\(Format.kg(total.maxWeight))" : ""))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct ExerciseDetailView: View {
    let exerciseName: String

    @Query(sort: \WorkoutEntry.date, order: .reverse) private var allEntries: [WorkoutEntry]

    private var entries: [WorkoutEntry] { allEntries.filter { $0.exerciseName == exerciseName } }
    private var items: [LogItem] { entries.map(\.logItem) }
    private var isWeighted: Bool { entries.contains { $0.addedWeight > 0 } }
    private var axisLabel: String { isWeighted ? "кг" : "Повторения" }

    var body: some View {
        List {
            Section {
                Chart(DiaryAnalytics.dailyProgress(items, exercise: exerciseName)) { point in
                    LineMark(x: .value("Дата", point.date), y: .value(axisLabel, point.value))
                        .foregroundStyle(Theme.orange)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                        .interpolationMethod(.monotone)
                    PointMark(x: .value("Дата", point.date), y: .value(axisLabel, point.value))
                        .foregroundStyle(Theme.pink)
                }
                .frame(height: 200)
                .padding(.vertical, 8)
            } header: {
                Text(isWeighted ? "Максимальное отягощение за тренировку" : "Повторений за тренировку")
            }

            Section {
                HStack {
                    StatTile(title: "Тренировок", value: "\(DiaryAnalytics.trainingDays(items).count)")
                    StatTile(title: "Повторений", value: "\(DiaryAnalytics.totalReps(items))")
                    StatTile(title: "Лучший подход", value: "\(entries.map(\.reps).max() ?? 0)")
                }
            }

            Section("История") {
                ForEach(entries) { entry in
                    HStack {
                        Text(entry.date.shortRu)
                        Spacer()
                        Text(entry.setsLabel + (entry.addedWeight > 0 ? " · +\(Format.kg(entry.addedWeight))" : ""))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
