import SwiftData
import SwiftUI

struct AttemptEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var profiles: [AthleteProfile]
    @Query(sort: \MaxAttempt.date) private var attempts: [MaxAttempt]

    var attempt: MaxAttempt?

    @State private var lift: Lift = .pullUp
    @State private var weight = 0.0
    @State private var bodyweight = 0.0
    @State private var date = Date.now
    @State private var isCompetition = false
    @State private var note = ""
    @State private var updateProfileWeight = true
    @State private var loaded = false

    private var previousBest: Double {
        attempts.filter { $0.lift == lift && $0 !== attempt }.map(\.addedWeight).max() ?? 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Движение", selection: $lift) {
                        ForEach(Lift.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    WeightField(title: "Отягощение", value: $weight)
                } footer: {
                    if previousBest > 0 {
                        Text(weight > previousBest
                             ? "Новый рекорд! \(Format.signedKg(weight - previousBest)) к прошлому лучшему (\(Format.kg(previousBest)))."
                             : "Текущий рекорд: \(Format.kg(previousBest)).")
                    }
                }

                Section {
                    WeightField(title: "Вес тела", value: $bodyweight, step: 0.1)
                    DatePicker("Дата", selection: $date, displayedComponents: .date)
                    Toggle("На соревнованиях", isOn: $isCompetition)
                    if attempt == nil {
                        Toggle("Обновить вес в профиле", isOn: $updateProfileWeight)
                    }
                }

                Section("Заметка") {
                    TextField("Судейство, самочувствие…", text: $note, axis: .vertical)
                        .lineLimit(1...4)
                }
            }
            .navigationTitle(attempt == nil ? "Попытка на 1ПМ" : "Редактирование")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить", action: save)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let attempt {
            lift = attempt.lift
            weight = attempt.addedWeight
            bodyweight = attempt.bodyweight
            date = attempt.date
            isCompetition = attempt.isCompetition
            note = attempt.note
        } else {
            bodyweight = profiles.first?.bodyweight ?? 0
            weight = attempts.last { $0.lift == lift }?.addedWeight ?? 0
        }
    }

    private func save() {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if let attempt {
            attempt.lift = lift
            attempt.addedWeight = weight
            attempt.bodyweight = bodyweight
            attempt.date = date
            attempt.isCompetition = isCompetition
            attempt.note = trimmedNote
        } else {
            context.insert(MaxAttempt(date: date, lift: lift, addedWeight: weight, bodyweight: bodyweight,
                                      isCompetition: isCompetition, note: trimmedNote))
            if updateProfileWeight, bodyweight > 0, let profile = profiles.first {
                profile.bodyweight = bodyweight
            }
        }
        dismiss()
    }
}

struct AttemptRow: View {
    let attempt: MaxAttempt

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: attempt.lift.symbol)
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(attempt.lift.title).font(.subheadline.weight(.medium))
                    if attempt.isCompetition {
                        Image(systemName: "medal.fill").foregroundStyle(.yellow).font(.caption)
                    }
                }
                Text("\(attempt.date.shortRu) · вес тела \(Format.kg(attempt.bodyweight))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("+\(Format.kg(attempt.addedWeight))")
                .font(.headline.monospacedDigit())
        }
    }
}

struct AttemptsListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \MaxAttempt.date, order: .reverse) private var attempts: [MaxAttempt]
    @State private var editing: MaxAttempt?
    @State private var filter: Lift?

    private var filtered: [MaxAttempt] {
        guard let filter else { return attempts }
        return attempts.filter { $0.lift == filter }
    }

    var body: some View {
        List {
            Picker("Фильтр", selection: $filter) {
                Text("Все").tag(Lift?.none)
                ForEach(Lift.allCases) { Text($0.title).tag(Lift?.some($0)) }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)

            ForEach(filtered) { attempt in
                Button { editing = attempt } label: { AttemptRow(attempt: attempt) }
                    .buttonStyle(.plain)
            }
            .onDelete { offsets in
                let items = filtered
                for index in offsets { context.delete(items[index]) }
            }
        }
        .navigationTitle("Попытки на 1ПМ")
        .sheet(item: $editing) { attempt in
            AttemptEditorView(attempt: attempt)
        }
    }
}
