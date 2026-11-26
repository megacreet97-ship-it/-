import SwiftData
import SwiftUI

struct DiaryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WorkoutEntry.date) private var entries: [WorkoutEntry]
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    @State private var showingNewEntry = false
    @State private var editingEntry: WorkoutEntry?

    private let calendar = Calendar.current

    private var dayEntries: [WorkoutEntry] {
        entries.filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var markedDays: Set<Date> {
        DiaryAnalytics.trainingDays(entries.map(\.logItem), calendar: calendar)
    }

    private var previousWorkoutDay: Date? {
        let start = calendar.startOfDay(for: selectedDate)
        return entries.last { $0.date < start }.map { calendar.startOfDay(for: $0.date) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    WeekStrip(selected: $selectedDate, markedDays: markedDays)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))

                if dayEntries.isEmpty {
                    Section {
                        ContentUnavailableView {
                            Label("Нет записей", systemImage: "figure.strengthtraining.functional")
                        } description: {
                            Text("Выберите упражнение и запишите повторения и подходы.")
                        } actions: {
                            Button("Добавить упражнение") { showingNewEntry = true }
                                .buttonStyle(.borderedProminent)
                            if let previousWorkoutDay {
                                Button("Повторить тренировку от \(previousWorkoutDay.shortRu)") {
                                    repeatWorkout(from: previousWorkoutDay)
                                }
                            }
                        }
                    }
                } else {
                    Section {
                        HStack {
                            StatTile(title: "Упражнений", value: "\(Set(dayEntries.map(\.exerciseName)).count)")
                            StatTile(title: "Подходов", value: "\(DiaryAnalytics.totalSets(dayEntries.map(\.logItem)))")
                            StatTile(title: "Повторений", value: "\(DiaryAnalytics.totalReps(dayEntries.map(\.logItem)))")
                        }
                    }

                    Section("Тренировка") {
                        ForEach(dayEntries) { entry in
                            Button { editingEntry = entry } label: { EntryRow(entry: entry) }
                                .buttonStyle(.plain)
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle(selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !calendar.isDateInToday(selectedDate) {
                        Button("Сегодня") { selectedDate = calendar.startOfDay(for: .now) }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingNewEntry = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Добавить упражнение")
                }
            }
            .sheet(isPresented: $showingNewEntry) {
                EntryEditorView(date: selectedDate, entry: nil)
            }
            .sheet(item: $editingEntry) { entry in
                EntryEditorView(date: entry.date, entry: entry)
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        let items = dayEntries
        for index in offsets { context.delete(items[index]) }
    }

    private func repeatWorkout(from day: Date) {
        let source = entries.filter { calendar.isDate($0.date, inSameDayAs: day) }
        for (offset, entry) in source.enumerated() {
            let date = calendar.date(byAdding: .minute, value: offset, to: selectedDate.atCurrentTime()) ?? selectedDate
            context.insert(WorkoutEntry(date: date, exerciseName: entry.exerciseName, lift: entry.lift,
                                        reps: entry.reps, sets: entry.sets, addedWeight: entry.addedWeight))
        }
    }
}

struct EntryRow: View {
    let entry: WorkoutEntry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.lift?.symbol ?? "dumbbell")
                .font(.title3)
                .foregroundStyle(entry.lift == nil ? Color.secondary : Color.accentColor)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.exerciseName).font(.body.weight(.medium))
                HStack(spacing: 6) {
                    Text("\(entry.sets) × \(entry.reps)")
                    if entry.addedWeight > 0 { Text("· +\(Format.kg(entry.addedWeight))") }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                if !entry.note.isEmpty {
                    Text(entry.note).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Spacer()
            Text("\(entry.sets * entry.reps)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
}

struct WeekStrip: View {
    @Binding var selected: Date
    let markedDays: Set<Date>

    private let calendar = Calendar.current

    var body: some View {
        let start = DiaryAnalytics.weekStart(for: selected, calendar: calendar)
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        HStack(spacing: 2) {
            Button { shift(by: -7) } label: { Image(systemName: "chevron.left") }
                .buttonStyle(.borderless)
            ForEach(days, id: \.self) { day in
                let isSelected = calendar.isDate(day, inSameDayAs: selected)
                Button { selected = day } label: {
                    VStack(spacing: 4) {
                        Text(day.formatted(.dateTime.weekday(.abbreviated)))
                            .font(.caption2)
                            .textCase(.uppercase)
                        Text(day.formatted(.dateTime.day()))
                            .font(.body.weight(.semibold))
                        Circle()
                            .fill(markedDays.contains(day) ? Color.accentColor : Color.clear)
                            .frame(width: 5, height: 5)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(isSelected ? Color.accentColor.opacity(0.18) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .foregroundStyle(calendar.isDateInToday(day) ? Color.accentColor : Color.primary)
                }
                .buttonStyle(.borderless)
            }
            Button { shift(by: 7) } label: { Image(systemName: "chevron.right") }
                .buttonStyle(.borderless)
        }
    }

    private func shift(by days: Int) {
        selected = calendar.date(byAdding: .day, value: days, to: selected) ?? selected
    }
}

extension Date {
    /// Same calendar day, but with the current wall-clock time, so entries keep their order within a day.
    func atCurrentTime(calendar: Calendar = .current) -> Date {
        let now = calendar.dateComponents([.hour, .minute, .second], from: .now)
        return calendar.date(bySettingHour: now.hour ?? 12, minute: now.minute ?? 0, second: now.second ?? 0, of: self) ?? self
    }
}
