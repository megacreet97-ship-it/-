import SwiftData
import SwiftUI

struct EntryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\Exercise.category), SortDescriptor(\Exercise.name)]) private var exercises: [Exercise]
    @Query private var profiles: [AthleteProfile]

    let date: Date
    let entry: WorkoutEntry?

    @State private var exerciseName = ""
    @State private var sets = 3
    @State private var reps = 10
    @State private var weight = 0.0
    @State private var note = ""
    @State private var saveAsMax = false
    @State private var loaded = false

    private var selectedExercise: Exercise? { exercises.first { $0.name == exerciseName } }
    private var lift: Lift? { selectedExercise?.lift ?? entry?.lift }
    private var bodyweight: Double { profiles.first?.bodyweight ?? 0 }

    private var categories: [String] {
        var seen = Set<String>()
        return exercises.map(\.category).filter { seen.insert($0).inserted }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Упражнение") {
                    Picker("Упражнение", selection: $exerciseName) {
                        if selectedExercise == nil {
                            Text(exerciseName.isEmpty ? "Не выбрано" : exerciseName).tag(exerciseName)
                        }
                        ForEach(categories, id: \.self) { category in
                            Section(category) {
                                ForEach(exercises.filter { $0.category == category }) { exercise in
                                    Text(exercise.name).tag(exercise.name)
                                }
                            }
                        }
                    }
                    .pickerStyle(.navigationLink)

                    NavigationLink("Добавить своё упражнение") {
                        ExerciseFormView { exerciseName = $0 }
                    }
                }

                Section {
                    Stepper(value: $sets, in: 1...50) {
                        LabeledContent("Подходы", value: "\(sets)")
                    }
                    Stepper(value: $reps, in: 1...300) {
                        LabeledContent("Повторения в подходе", value: "\(reps)")
                    }
                    WeightField(title: "Отягощение", value: $weight)
                } header: {
                    Text("Объём")
                } footer: {
                    Text("Всего: \(sets * reps) повторений. Отягощение 0 — с собственным весом.")
                }

                if let lift {
                    Section {
                        if reps == 1 {
                            Toggle("Записать как попытку на 1ПМ", isOn: $saveAsMax)
                        } else if let estimate = OneRepMax.estimatedAddedWeight(added: weight, bodyweight: bodyweight, reps: reps) {
                            LabeledContent("Расчётный 1ПМ", value: Format.kg(estimate))
                        }
                    } header: {
                        Text(lift.fullTitle)
                    } footer: {
                        Text(reps == 1
                             ? "Попытка попадёт в раздел «Мастер спорта» и будет учтена в рекордах."
                             : "Оценка по формулам Эпли и Бжицки от веса тела \(Format.kg(bodyweight)) + отягощение. Точна до ~\(OneRepMax.maxReliableReps) повторений.")
                    }
                }

                Section("Заметка") {
                    TextField("Самочувствие, техника, пульс…", text: $note, axis: .vertical)
                        .lineLimit(1...4)
                }
            }
            .navigationTitle(entry == nil ? "Новая запись" : "Редактирование")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить", action: save)
                        .disabled(exerciseName.isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let entry {
            exerciseName = entry.exerciseName
            sets = entry.sets
            reps = entry.reps
            weight = entry.addedWeight
            note = entry.note
        } else if let first = exercises.first {
            exerciseName = first.name
        }
    }

    private func save() {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let entryDate: Date
        if let entry {
            entry.exerciseName = exerciseName
            entry.lift = lift
            entry.sets = sets
            entry.reps = reps
            entry.addedWeight = weight
            entry.note = trimmedNote
            entryDate = entry.date
        } else {
            entryDate = date.atCurrentTime()
            context.insert(WorkoutEntry(date: entryDate, exerciseName: exerciseName, lift: lift,
                                        reps: reps, sets: sets, addedWeight: weight, note: trimmedNote))
        }
        if saveAsMax, reps == 1, let lift {
            context.insert(MaxAttempt(date: entryDate, lift: lift, addedWeight: weight, bodyweight: bodyweight))
        }
        dismiss()
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
                Text("Если упражнение — вариант подтягиваний или брусьев с отягощением, записи по нему попадут в аналитику стритлифтинга.")
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
