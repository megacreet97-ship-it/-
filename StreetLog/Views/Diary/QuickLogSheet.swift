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
    /// Reps of each set in "по подходам" mode; nil when all sets are equal.
    @State private var setList: [Int]?
    @State private var weight = 0.0
    @State private var note = ""
    @State private var saveAsMax = false
    @State private var loaded = false

    private var isEditing: Bool { draft.entry != nil }
    private var selectedExercise: Exercise? { exercises.first { $0.name == exerciseName } }
    private var lift: Lift? { selectedExercise?.lift ?? draft.entry?.lift }
    private var bodyweight: Double { profiles.first?.bodyweight ?? 0 }
    private var tint: Color { lift?.color ?? Theme.orange }
    private var effectiveSets: [Int] { setList ?? Array(repeating: reps, count: sets) }
    private var totalReps: Int { effectiveSets.reduce(0, +) }
    private var bestReps: Int { effectiveSets.max() ?? reps }
    private var canRecord: Bool { setList == nil && reps == 1 }
    private var perSetBinding: Binding<Bool> {
        Binding(get: { setList != nil }, set: { perSet in
            withAnimation(.snappy) {
                if perSet {
                    setList = Array(repeating: reps, count: sets)
                } else if let list = setList {
                    sets = list.count
                    reps = list.first ?? reps
                    setList = nil
                }
            }
        })
    }

    private var lastEntry: WorkoutEntry? {
        entries.last { $0.exerciseName == exerciseName && $0 !== draft.entry }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    exerciseSelector
                    if let lastEntry { lastTimeCard(lastEntry) }
                    Picker("Повторения", selection: perSetBinding) {
                        Text("Одинаково").tag(false)
                        Text("По подходам").tag(true)
                    }
                    .pickerStyle(.segmented)
                    if setList != nil {
                        perSetCard
                    } else {
                        BigStepper(title: "Подходы", value: $sets.asDouble, step: 1, range: 1...50)
                        BigStepper(title: "Повторения в подходе", value: $reps.asDouble, step: 1, range: 1...300)
                    }
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
                Text(entry.setsLabel + (entry.addedWeight > 0 ? " · +\(Format.kg(entry.addedWeight))" : ""))
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

    private var perSetCard: some View {
        VStack(spacing: 10) {
            ForEach(Array(effectiveSets.indices), id: \.self) { index in
                HStack(spacing: 8) {
                    Text("\(index + 1)-й")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 34, alignment: .leading)
                    BigStepper(title: "", value: setBinding(index), step: 1, range: 1...300, compact: true)
                    Button(role: .destructive) {
                        withAnimation(.snappy) { _ = setList?.remove(at: index) }
                    } label: {
                        Image(systemName: "trash").foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .disabled((setList?.count ?? 0) <= 1)
                    .opacity((setList?.count ?? 0) <= 1 ? 0.3 : 1)
                    .accessibilityLabel("Удалить \(index + 1)-й подход")
                }
            }
            Button {
                withAnimation(.snappy) { setList?.append(setList?.last ?? reps) }
            } label: {
                Label("Подход", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Theme.elevated, in: Capsule())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.orange)
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func setBinding(_ index: Int) -> Binding<Double> {
        Binding(
            get: { Double(setList?[safe: index] ?? reps) },
            set: { newValue in
                guard var list = setList, list.indices.contains(index) else { return }
                list[index] = Int(newValue.rounded())
                setList = list
            }
        )
    }

    private var totalsCard: some View {
        HStack {
            StatTile(title: "Всего повторений", value: "\(totalReps)",
                     caption: setList.map { SetsFormat.label(sets: $0.count, reps: reps, setReps: $0) })
            if weight > 0 {
                StatTile(title: "Тоннаж", value: Format.kg(weight * Double(totalReps)))
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
            if canRecord {
                Toggle("Засчитать как рекорд на 1 раз", isOn: $saveAsMax)
                    .tint(lift.color)
                Text("Попытка попадёт во вкладку «Мастер спорта».")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let estimate = OneRepMax.estimatedAddedWeight(added: weight, bodyweight: bodyweight, reps: bestReps) {
                HStack(alignment: .firstTextBaseline) {
                    Text(setList == nil ? "Расчётный максимум на 1 раз" : "Расчётный максимум (лучший подход)").font(.subheadline)
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
        setList = entry.setReps
        weight = entry.addedWeight
    }

    private func save() {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let shape = setList.map(SetsFormat.normalize) ?? (sets: sets, reps: reps, setReps: nil)
        let entryDate: Date
        if let entry = draft.entry {
            entry.exerciseName = exerciseName
            entry.lift = lift
            entry.sets = shape.sets
            entry.reps = shape.reps
            entry.setReps = shape.setReps
            entry.addedWeight = weight
            entry.note = trimmedNote
            entryDate = entry.date
        } else {
            entryDate = draft.date.atCurrentTime()
            context.insert(WorkoutEntry(date: entryDate, exerciseName: exerciseName, lift: lift,
                                        reps: shape.reps, sets: shape.sets, addedWeight: weight, note: trimmedNote,
                                        setReps: shape.setReps))
        }
        if saveAsMax, canRecord, let lift {
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
    @State private var categoryFilter: String?

    private var allCategories: [String] {
        Array(Set(exercises.map(\.category))).sorted(by: ExerciseLibrary.areInOrder)
    }

    private var filtered: [Exercise] {
        if !search.isEmpty { return exercises.filter { $0.name.localizedCaseInsensitiveContains(search) } }
        guard let categoryFilter else { return exercises }
        return exercises.filter { $0.category == categoryFilter }
    }

    private var categories: [String] {
        Array(Set(filtered.map(\.category))).sorted(by: ExerciseLibrary.areInOrder)
    }

    var body: some View {
        List {
            if search.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        chip("Все", isOn: categoryFilter == nil) { categoryFilter = nil }
                        ForEach(allCategories, id: \.self) { category in
                            chip(category, isOn: categoryFilter == category) { categoryFilter = category }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                .listRowBackground(Color.clear)
            }
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
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Поиск среди \(exercises.count) упражнений")
        .navigationTitle("Упражнение")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func chip(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(isOn ? Color.white : Color.secondary)
                .background {
                    Capsule().fill(isOn ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Theme.card))
                }
        }
        .buttonStyle(.plain)
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

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
