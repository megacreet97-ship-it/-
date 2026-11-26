import SwiftData
import SwiftUI

struct LogDraft: Identifiable {
    let id = UUID()
    var date: Date
    var entry: WorkoutEntry?
    var exerciseName: String?
}

struct DiaryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WorkoutEntry.date) private var entries: [WorkoutEntry]
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    @State private var draft: LogDraft?
    @State private var choosingDayToCopy = false

    private let calendar = Calendar.current

    private var dayEntries: [WorkoutEntry] {
        entries.filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var dayItems: [LogItem] { dayEntries.map(\.logItem) }

    private var markedDays: Set<Date> {
        DiaryAnalytics.trainingDays(entries.map(\.logItem), calendar: calendar)
    }

    private var previousWorkoutDay: Date? {
        let start = calendar.startOfDay(for: selectedDate)
        return entries.last { $0.date < start }.map { calendar.startOfDay(for: $0.date) }
    }

    /// Latest earlier workout on the same weekday, e.g. last Wednesday when a Wednesday is selected.
    private var sameWeekdayWorkoutDay: Date? {
        let start = calendar.startOfDay(for: selectedDate)
        let weekday = calendar.component(.weekday, from: selectedDate)
        return entries.last { $0.date < start && calendar.component(.weekday, from: $0.date) == weekday }
            .map { calendar.startOfDay(for: $0.date) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    DayStrip(selected: $selectedDate, markedDays: markedDays)
                    summaryCard
                    workoutSection
                }
                .padding(.horizontal)
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
            .background(Color(.systemBackground))
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !calendar.isDateInToday(selectedDate) {
                        Button("Сегодня") {
                            withAnimation(.snappy) { selectedDate = calendar.startOfDay(for: .now) }
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    draft = LogDraft(date: selectedDate)
                } label: {
                    Label("Добавить упражнение", systemImage: "plus")
                }
                .buttonStyle(GradientButtonStyle())
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .sheet(item: $draft) { draft in
                QuickLogSheet(draft: draft)
            }
            .sheet(isPresented: $choosingDayToCopy) {
                CopyDaySheet(entries: entries, target: selectedDate) { day in
                    repeatWorkout(from: day)
                }
            }
        }
    }

    private var title: String {
        if calendar.isDateInToday(selectedDate) { return "Сегодня" }
        if calendar.isDateInYesterday(selectedDate) { return "Вчера" }
        return selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide)).capitalized
    }

    // MARK: Sections

    private var summaryCard: some View {
        HStack(spacing: 0) {
            summaryMetric(value: "\(DiaryAnalytics.totalReps(dayItems))", label: "повторений", highlight: true)
            Divider().frame(height: 44).overlay(Color.white.opacity(0.1))
            summaryMetric(value: "\(DiaryAnalytics.totalSets(dayItems))", label: "подходов")
            Divider().frame(height: 44).overlay(Color.white.opacity(0.1))
            summaryMetric(value: "\(Set(dayEntries.map(\.exerciseName)).count)", label: "упражнений")
        }
        .padding(.vertical, 18)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).strokeBorder(Color.white.opacity(0.06)))
    }

    private func summaryMetric(value: String, label: String, highlight: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(highlight ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Color.primary))
                .contentTransition(.numericText())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var workoutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "Тренировка", trailing: dayEntries.isEmpty ? nil : "\(dayEntries.count) зап.")
            if dayEntries.isEmpty {
                emptyState
            } else {
                ForEach(dayEntries) { entry in
                    EntryCard(entry: entry,
                              onAddSet: { addSet(to: entry) },
                              onEdit: { draft = LogDraft(date: entry.date, entry: entry) },
                              onDuplicate: { duplicate(entry) },
                              onDelete: { withAnimation { context.delete(entry) } })
                }
                Text("Нажмите на запись, чтобы изменить. Удерживайте — чтобы дублировать или удалить.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                if markedDays.count > 1 {
                    Button { choosingDayToCopy = true } label: {
                        Label("Скопировать из другого дня", systemImage: "doc.on.doc")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            IconBadge(systemImage: "figure.strengthtraining.functional", size: 64)
            Text("Записей пока нет").font(.headline)
            Text("Нажмите «Добавить упражнение» внизу — недавние упражнения будут сверху списка.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let sameWeekdayWorkoutDay {
                repeatButton("Как \(Self.lastWeekday[calendar.component(.weekday, from: selectedDate) - 1]) · \(sameWeekdayWorkoutDay.dayMonth)",
                             day: sameWeekdayWorkoutDay)
            }
            if let previousWorkoutDay, previousWorkoutDay != sameWeekdayWorkoutDay {
                repeatButton("Повторить от \(previousWorkoutDay.dayMonth)", day: previousWorkoutDay)
            }
            if !markedDays.isEmpty {
                Button("Выбрать другой день") { choosingDayToCopy = true }
                    .font(.subheadline.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }

    private static let lastWeekday = ["в прошлое воскресенье", "в прошлый понедельник", "в прошлый вторник", "в прошлую среду",
                                      "в прошлый четверг", "в прошлую пятницу", "в прошлую субботу"]

    private func repeatButton(_ title: String, day: Date) -> some View {
        Button {
            repeatWorkout(from: day)
        } label: {
            Label(title, systemImage: "arrow.clockwise")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Theme.elevated, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: Actions

    private func addSet(to entry: WorkoutEntry) {
        withAnimation(.snappy) {
            if var list = entry.setReps, let last = list.last {
                list.append(last)
                entry.setReps = list
                entry.sets = list.count
            } else {
                entry.sets += 1
            }
        }
    }

    private func duplicate(_ entry: WorkoutEntry) {
        context.insert(WorkoutEntry(date: entry.date.addingTimeInterval(1), exerciseName: entry.exerciseName, lift: entry.lift,
                                    reps: entry.reps, sets: entry.sets, addedWeight: entry.addedWeight, note: entry.note,
                                    setReps: entry.setReps))
    }

    private func repeatWorkout(from day: Date) {
        let source = entries.filter { calendar.isDate($0.date, inSameDayAs: day) }.sorted { $0.date < $1.date }
        let base = selectedDate.atCurrentTime()
        for (offset, entry) in source.enumerated() {
            context.insert(WorkoutEntry(date: base.addingTimeInterval(Double(offset)), exerciseName: entry.exerciseName, lift: entry.lift,
                                        reps: entry.reps, sets: entry.sets, addedWeight: entry.addedWeight, setReps: entry.setReps))
        }
    }
}

struct CopyDaySheet: View {
    let entries: [WorkoutEntry]
    let target: Date
    var onPick: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var sameWeekdayOnly = false

    private let calendar = Calendar.current
    private static let weekdayPlural = ["воскресенья", "понедельники", "вторники", "среды", "четверги", "пятницы", "субботы"]

    private var weekday: Int { calendar.component(.weekday, from: target) }

    private var days: [(day: Date, entries: [WorkoutEntry])] {
        let targetDay = calendar.startOfDay(for: target)
        let grouped = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.date) }
        return grouped
            .filter { $0.key != targetDay }
            .map { (day: $0.key, entries: $0.value.sorted { $0.date < $1.date }) }
            .sorted { $0.day > $1.day }
            .prefix(90)
            .map { $0 }
    }

    var body: some View {
        let all = days
        let same = all.filter { calendar.component(.weekday, from: $0.day) == weekday }
        NavigationStack {
            List {
                Section {
                    if !same.isEmpty && same.count < all.count {
                        Toggle("Только \(Self.weekdayPlural[weekday - 1])", isOn: $sameWeekdayOnly)
                    }
                } footer: {
                    Text("Упражнения выбранного дня добавятся в \(calendar.isDateInToday(target) ? "сегодня" : target.dayMonth) с теми же подходами и весами — потом их можно поменять.")
                }
                ForEach(sameWeekdayOnly ? same : all, id: \.day) { item in
                    Button {
                        onPick(item.day)
                        dismiss()
                    } label: {
                        dayRow(item.day, entries: item.entries)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Скопировать тренировку")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
            }
        }
    }

    private static func title(for day: Date) -> String {
        let text = day.formatted(.dateTime.weekday(.wide).day().month(.wide))
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    private func dayRow(_ day: Date, entries: [WorkoutEntry]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(Self.title(for: day)).font(.headline)
                Spacer()
                if calendar.component(.weekday, from: day) == weekday {
                    Pill(text: "тот же день недели")
                }
            }
            Text("\(entries.count) упр. · \(entries.reduce(0) { $0 + $1.sets }) подх.").font(.caption).foregroundStyle(.secondary)
            Text(entries.map { $0.exerciseName + " " + $0.setsLabel + ($0.addedWeight > 0 ? " +\(Format.number($0.addedWeight))" : "") }
                .joined(separator: " · "))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Rows

struct EntryCard: View {
    let entry: WorkoutEntry
    var onAddSet: () -> Void
    var onEdit: () -> Void
    var onDuplicate: () -> Void
    var onDelete: () -> Void

    private var tint: Color { entry.lift?.color ?? Theme.orange }

    var body: some View {
        HStack(spacing: 14) {
            IconBadge(systemImage: entry.lift?.symbol ?? "dumbbell.fill", tint: tint, size: 44)
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.exerciseName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(entry.setsLabel)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    if entry.addedWeight > 0 {
                        Pill(text: "+\(Format.kg(entry.addedWeight))", tint: tint)
                    }
                }
                if !entry.note.isEmpty {
                    Text(entry.note).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            Button(action: onAddSet) {
                VStack(spacing: 2) {
                    Image(systemName: "plus").font(.headline)
                    Text("подход").font(.caption2)
                }
                .foregroundStyle(tint)
                .frame(width: 58, height: 52)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Добавить подход")
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onTapGesture(perform: onEdit)
        .contextMenu {
            Button("Изменить", systemImage: "pencil", action: onEdit)
            Button("Дублировать", systemImage: "plus.square.on.square", action: onDuplicate)
            Button("Удалить", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }
}

struct DayStrip: View {
    @Binding var selected: Date
    let markedDays: Set<Date>

    @State private var position: Date?
    @State private var choosingDate = false
    private let calendar = Calendar.current

    private var days: [Date] {
        let today = calendar.startOfDay(for: .now)
        let first = min(calendar.date(byAdding: .day, value: -56, to: today) ?? today,
                        calendar.date(byAdding: .day, value: -14, to: calendar.startOfDay(for: selected)) ?? today)
        let count = calendar.dateComponents([.day], from: first, to: today).day ?? 56
        return (0...(count + 7)).compactMap { calendar.date(byAdding: .day, value: $0, to: first) }
    }

    private var monthTitle: String {
        let text = (position ?? selected).formatted(.dateTime.month(.wide).year())
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(monthTitle).font(.headline).contentTransition(.numericText())
                Spacer()
                Button { choosingDate = true } label: {
                    Label("Выбрать дату", systemImage: "calendar").font(.subheadline.weight(.semibold))
                }
            }
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(days, id: \.self) { day in
                        HStack(spacing: 8) {
                            if calendar.component(.day, from: day) == 1 {
                                Text(day.formatted(.dateTime.month(.abbreviated)))
                                    .font(.caption2.weight(.heavy))
                                    .textCase(.uppercase)
                                    .foregroundStyle(Theme.orange)
                                    .fixedSize()
                                    .rotationEffect(.degrees(-90))
                                    .frame(width: 14)
                            }
                            dayPill(day)
                        }
                        .id(day)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
            .scrollPosition(id: $position, anchor: .center)
            .padding(.horizontal, -16)
            .frame(height: 84)
            .onAppear { position = calendar.startOfDay(for: selected) }
            .onChange(of: selected) { _, newValue in
                withAnimation(.snappy) { position = calendar.startOfDay(for: newValue) }
            }
        }
        .sheet(isPresented: $choosingDate) {
            DateJumpSheet(selected: $selected)
                .presentationDetents([.medium, .large])
        }
    }

    private func dayPill(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selected)
        let isToday = calendar.isDateInToday(day)
        return Button {
            withAnimation(.snappy) { selected = day }
        } label: {
            VStack(spacing: 6) {
                Text(day.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.caption2.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Color.secondary)
                Text(day.formatted(.dateTime.day()))
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(isSelected ? Color.white : (isToday ? Theme.orange : Color.primary))
                Circle()
                    .fill(markedDays.contains(day) ? (isSelected ? Color.white : Theme.orange) : Color.clear)
                    .frame(width: 6, height: 6)
            }
            .frame(width: 50, height: 76)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Theme.card))
            }
        }
        .buttonStyle(.plain)
    }
}

struct DateJumpSheet: View {
    @Binding var selected: Date
    @Environment(\.dismiss) private var dismiss
    @State private var date: Date

    init(selected: Binding<Date>) {
        _selected = selected
        _date = State(initialValue: selected.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            DatePicker("Дата", selection: $date, in: ...(Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now), displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(Theme.orange)
                .padding(.horizontal)
                .navigationTitle("Выбрать дату")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Готово") {
                            selected = Calendar.current.startOfDay(for: date)
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
            Spacer()
        }
    }
}

extension Date {
    /// Same calendar day, but with the current wall-clock time, so entries keep their order within a day.
    func atCurrentTime(calendar: Calendar = .current) -> Date {
        let now = calendar.dateComponents([.hour, .minute, .second], from: .now)
        return calendar.date(bySettingHour: now.hour ?? 12, minute: now.minute ?? 0, second: now.second ?? 0, of: self) ?? self
    }
}
