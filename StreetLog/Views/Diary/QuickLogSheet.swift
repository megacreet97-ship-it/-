import SwiftData
import SwiftUI

struct QuickLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \WorkoutEntry.date) private var entries: [WorkoutEntry]
    @Query(sort: \Exercise.createdAt) private var exercises: [Exercise]
    @Query private var profiles: [AthleteProfile]

    let draft: LogDraft

    @State private var exerciseName = ""
    @State private var sets = 3
    @State private var reps = 10
    @State private var weight = 0.0
    @State private var note = ""
    @State private var saveAsMax = false
    @State private var loaded = false

    private var isEditing: Bool { draft.entry != nil }
    private var selectedExercise: Exercise? { exercises.first { $0.name == exerciseName } }
    private var lift: Lift? { selectedExercise?.lift ?? draft.entry?.lift }
    private var bodyweight: Double { profiles.first?.bodyweight ?? 0 }
    private var tint: Color { lift?.color ?? Theme.orange }

    private var lastEntry: WorkoutEntry? {
        entries.last { $0.exerciseName == exerciseName && $0 !== draft.entry }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    exerciseSelector
                    if let lastEntry { lastTimeCard(lastEntry) }
                    BigStepper(title: "Подходы", value: $sets.asDouble, step: 1, range: 1...50)
                    BigStepper(title: "Повторения в подходе", value: $reps.asDouble, step: 1, range: 1...300)
                    BigStepper(title: "Отягощение", value: $weight, step: 1.25, range: 0...300, unit: "кг",
                               quickSteps: [-2.5, 1.25, 2.5, 5])
                    totalsCard
                    if let lift { liftCard(lift) }
                    noteField
                }
                .padding()
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemBackground))
            .safeAreaInset(edge: .bottom) {
                Button(action: save) {
                    Label(isEditing ? "Сохранить изменения" : "Записать", systemImage: "checkmark")
                }
                .buttonStyle(GradientButtonStyle())
                .disabled(exerciseName.isEmpty)
                .opacity(exerciseName.isEmpty ? 0.5 : 1)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .background(.ultraThinMaterial)
            }
            .navigationTitle(isEditing ? "Изменить запись" : "Новая запись")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                if let entry = draft.entry {
                    ToolbarItem(placement: .destructiveAction) {
                        Button(role: .destructive) {
                            context.delete(entry)
                            dismiss()
                        } label: {
                            Image(systemName: "trash")
                        }
                        .tint(.red)
                    }
                }
            }
            .onAppear(perform: load)
            .onChange(of: exerciseName) { _, _ in
                if loaded && !isEditing { prefillFromLast() }
            }
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: Parts

    private var exerciseSelector: some View {
        NavigationLink {
            ExercisePickerView(selection: $exerciseName)
        } label: {
            HStack(spacing: 14) {
                IconBadge(systemImage: lift?.symbol ?? "dumbbell.fill", tint: tint, size: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Упражнение").font(.caption).foregroundStyle(.secondary)
                    Text(exerciseName.isEmpty ? "Выберите упражнение" : exerciseName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func lastTimeCard(_ entry: WorkoutEntry) -> some View {
        HStack {
            Image(systemName: "clock.arrow.circlepath").foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("В прошлый раз · \(entry.date.dayMonth)").font(.caption).foregroundStyle(.secondary)
                Text("\(entry.sets) × \(entry.reps)" + (entry.addedWeight > 0 ? " · +\(Format.kg(entry.addedWeight))" : ""))
                    .font(.subheadline.weight(.semibold))
            }
            Spacer()
            Button("Подставить") { apply(entry) }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var totalsCard: some View {
        HStack {
            StatTile(title: "Всего повторений", value: "\(sets * reps)")
            if weight > 0 {
                StatTile(title: "Тоннаж", value: Format.kg(weight * Double(sets * reps)))
            }
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func liftCard(_ lift: Lift) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(lift.fullTitle, systemImage: "trophy.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(lift.color)
            if reps == 1 {
                Toggle("Засчитать как рекорд на 1 раз", isOn: $saveAsMax)
                    .tint(lift.color)
                Text("Попытка попадёт во вкладку «Мастер спорта».")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let estimate = OneRepMax.estimatedAddedWeight(added: weight, bodyweight: bodyweight, reps: reps) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Расчётный максимум на 1 раз").font(.subheadline)
                    Spacer()
                    Text("+\(Format.kg(estimate))").font(.headline).monospacedDigit()
                }
                Text("По формулам Эпли и Бжицки от веса тела \(Format.kg(bodyweight)) с отягощением.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(lift.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var noteField: some View {
        TextField("Заметка: самочувствие, техника…", text: $note, axis: .vertical)
            .lineLimit(1...4)
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: Logic

    private func load() {
        guard !loaded else { return }
        if let entry = draft.entry {
            exerciseName = entry.exerciseName
            apply(entry)
            note = entry.note
        } else {
            exerciseName = draft.exerciseName
                ?? entries.last?.exerciseName
                ?? exercises.first(where: { $0.lift == .pullUp })?.name
                ?? exercises.first?.name
                ?? ""
            prefillFromLast()
        }
        DispatchQueue.main.async { loaded = true }
    }

    private func prefillFromLast() {
        if let lastEntry { apply(lastEntry) }
    }

    private func apply(_ entry: WorkoutEntry) {
        sets = entry.sets
        reps = entry.reps
        weight = entry.addedWeight
    }

    private func save() {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let entryDate: Date
        if let entry = draft.entry {
            entry.exerciseName = exerciseName
            entry.lift = lift
            entry.sets = sets
            entry.reps = reps
            entry.addedWeight = weight
            entry.note = trimmedNote
            entryDate = entry.date
        } else {
            entryDate = draft.date.atCurrentTime()
            context.insert(WorkoutEntry(date: entryDate, exerciseName: exerciseName, lift: lift,
                                        reps: reps, sets: sets, addedWeight: weight, note: trimmedNote))
        }
        if saveAsMax, reps == 1, let lift {
            context.insert(MaxAttempt(date: entryDate, lift: lift, addedWeight: weight, bodyweight: bodyweight))
        }
        dismiss()
    }
}

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\Exercise.category), SortDescriptor(\Exercise.name)]) private var exercises: [Exercise]
    @Binding var selection: String
    @State private var search = ""

    private var filtered: [Exercise] {
        search.isEmpty ? exercises : exercises.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    private var categories: [String] {
        var seen = Set<String>()
        let all = filtered.map(\.category).filter { seen.insert($0).inserted }
        return all.sorted { lhs, rhs in
            if lhs == "Стритлифтинг" { return true }
            if rhs == "Стритлифтинг" { return false }
            return lhs < rhs
        }
    }

    var body: some View {
        List {
            ForEach(categories, id: \.self) { category in
                Section(category) {
                    ForEach(filtered.filter { $0.category == category }) { exercise in
                        Button {
                            selection = exercise.name
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                IconBadge(systemImage: exercise.lift?.symbol ?? "dumbbell.fill",
                                          tint: exercise.lift?.color ?? Theme.orange, size: 32)
                                Text(exercise.name).foregroundStyle(.primary)
                                Spacer()
                                if exercise.name == selection {
                                    Image(systemName: "checkmark").foregroundStyle(Theme.orange)
                                }
                            }
                        }
                    }
                }
            }
            Section {
                NavigationLink {
                    ExerciseFormView { name in
                        selection = name
                    }
                } label: {
                    Label("Создать своё упражнение", systemImage: "plus.circle.fill")
                        .foregroundStyle(Theme.orange)
                }
            }
        }
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Поиск упражнения")
        .navigationTitle("Упражнение")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ExerciseFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var exercises: [Exercise]

    var onCreate: (String) -> Void = { _ in }

    @State private var name = ""
    @State private var category = "Своё"
    @State private var lift: Lift?

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isDuplicate: Bool { exercises.contains { $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame } }

    var body: some View {
        Form {
            Section {
                TextField("Название", text: $name)
                TextField("Категория", text: $category)
            } footer: {
                if isDuplicate { Text("Такое упражнение уже есть.").foregroundStyle(.red) }
            }
            Section {
                Picker("Соревновательное движение", selection: $lift) {
                    Text("Нет").tag(Lift?.none)
                    ForEach(Lift.allCases) { lift in
                        Text(lift.title).tag(Lift?.some(lift))
                    }
                }
            } footer: {
                Text("Если это вариант подтягиваний или брусьев с отягощением, записи попадут в аналитику стритлифтинга.")
            }
        }
        .navigationTitle("Новое упражнение")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Создать") {
                    let cleanCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
                    context.insert(Exercise(name: trimmedName, category: cleanCategory.isEmpty ? "Своё" : cleanCategory, lift: lift))
                    onCreate(trimmedName)
                    dismiss()
                }
                .disabled(trimmedName.isEmpty || isDuplicate)
            }
        }
    }
}
