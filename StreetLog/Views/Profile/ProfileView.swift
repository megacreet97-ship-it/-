import SwiftData
import SwiftUI

struct ProfileView: View {
    @Query private var profiles: [AthleteProfile]

    var body: some View {
        NavigationStack {
            Group {
                if let profile = profiles.first {
                    ProfileForm(profile: profile)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Профиль")
        }
    }
}

struct ProfileForm: View {
    @Bindable var profile: AthleteProfile
    @Query(sort: \WorkoutEntry.date) private var entries: [WorkoutEntry]
    @Query(sort: \MaxAttempt.date) private var attempts: [MaxAttempt]

    private var autoTotal: Binding<Bool> {
        Binding(
            get: { profile.targetTotal == 0 },
            set: { profile.targetTotal = $0 ? 0 : profile.targetPullUp + profile.targetDip }
        )
    }

    private var hasCompetition: Binding<Bool> {
        Binding(
            get: { profile.competitionDate != nil },
            set: { enabled in
                profile.competitionDate = enabled
                    ? Calendar.current.date(byAdding: .weekOfYear, value: 12, to: .now)
                    : nil
            }
        )
    }

    private var competitionDate: Binding<Date> {
        Binding(get: { profile.competitionDate ?? .now }, set: { profile.competitionDate = $0 })
    }

    private var federation: Binding<Federation> {
        Binding(get: { profile.federation }, set: { profile.federation = $0; profile.applyStandard() })
    }

    private var weightClassLimit: Binding<Double> {
        Binding(get: { profile.weightClassLimit }, set: { profile.weightClassLimit = $0; profile.applyStandard() })
    }

    private var goalRank: Binding<SportRank> {
        Binding(get: { profile.goalRank }, set: { profile.goalRank = $0; profile.applyStandard() })
    }

    private var suggestedClass: WeightClassStandard? {
        Standards.classFor(bodyweight: profile.bodyweight, federation: profile.federation)
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(Theme.accentGradient)
                        if let initial = profile.name.first {
                            Text(String(initial).uppercased())
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.white)
                        } else {
                            Image(systemName: "person.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Ваше имя", text: $profile.name).font(.headline)
                        Text("\(profile.federation.title) · \(profile.weightClass) · цель \(profile.goalRank.title)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
                WeightField(title: "Вес тела", value: $profile.bodyweight, step: 0.1)
            } footer: {
                if let suggestedClass, suggestedClass.limit != profile.weightClassLimit {
                    Button("По весу вы проходите в категорию \(suggestedClass.title) — выбрать её") {
                        weightClassLimit.wrappedValue = suggestedClass.limit
                    }
                    .font(.footnote)
                    .tint(Theme.orange)
                }
            }

            Section {
                Picker("Федерация", selection: federation) {
                    ForEach(Federation.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Весовая категория", selection: weightClassLimit) {
                    ForEach(Standards.classes(for: profile.federation)) { Text($0.title).tag($0.limit) }
                    Text("Своя цель").tag(0.0)
                }
                Picker("Звание", selection: goalRank) {
                    ForEach(SportRank.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .disabled(profile.standard == nil)
            } header: {
                Text("Цель")
            } footer: {
                if profile.standard != nil {
                    Text("Норматив подставляется из таблицы \(profile.federation.title). Звание в двоеборье даётся по сумме; цели по движениям — её раскладка, их можно поправить ниже.")
                } else {
                    Text("Своя цель: введите значения вручную, например для другой весовой категории.")
                }
            }

            Section {
                if profile.standard == nil {
                    LabeledContent("Весовая категория") {
                        TextField("например, до 82,5 кг", text: $profile.weightClass)
                            .multilineTextAlignment(.trailing)
                    }
                }
                WeightField(title: "Подтягивания", value: $profile.targetPullUp)
                WeightField(title: "Брусья", value: $profile.targetDip)
                if profile.standard == nil {
                    Toggle("Сумма = подтягивания + брусья", isOn: autoTotal)
                }
                if profile.standard == nil && !autoTotal.wrappedValue {
                    WeightField(title: "Сумма", value: $profile.targetTotal)
                } else {
                    LabeledContent("Сумма", value: Format.kg(profile.goalTotal))
                }
            } header: {
                Text("Целевые веса (отягощение)")
            }

            Section("Соревнования") {
                Toggle("Дата старта", isOn: hasCompetition)
                if profile.competitionDate != nil {
                    DatePicker("Дата", selection: competitionDate, displayedComponents: .date)
                    TextField("Название турнира", text: $profile.competitionName)
                }
            }

            Section {
                NavigationLink("Упражнения") { ExercisesView() }
                ShareLink(item: CSVExport.diary(entries), preview: SharePreview("Дневник тренировок (CSV)")) {
                    Label("Экспорт дневника (CSV)", systemImage: "square.and.arrow.up")
                }
                ShareLink(item: CSVExport.attempts(attempts), preview: SharePreview("Попытки на 1ПМ (CSV)")) {
                    Label("Экспорт попыток (CSV)", systemImage: "square.and.arrow.up")
                }
            } header: {
                Text("Данные")
            } footer: {
                Text("Данные хранятся только на iPhone. Делайте экспорт перед удалением приложения.")
            }
        }
    }
}

struct ExercisesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\Exercise.category), SortDescriptor(\Exercise.name)]) private var exercises: [Exercise]

    private var categories: [String] {
        Array(Set(exercises.map(\.category))).sorted(by: ExerciseLibrary.areInOrder)
    }

    var body: some View {
        List {
            ForEach(categories, id: \.self) { category in
                let items = exercises.filter { $0.category == category }
                Section(category) {
                    ForEach(items) { exercise in
                        HStack {
                            Text(exercise.name)
                            Spacer()
                            if let lift = exercise.lift {
                                Image(systemName: lift.symbol).foregroundStyle(.tint)
                            }
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets { context.delete(items[index]) }
                    }
                }
            }
        }
        .navigationTitle("Упражнения")
        .toolbar {
            NavigationLink { ExerciseFormView() } label: { Image(systemName: "plus") }
        }
    }
}

enum CSVExport {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    private static func escape(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static func diary(_ entries: [WorkoutEntry]) -> String {
        var lines = ["date;exercise;sets;reps;reps_by_set;added_kg;note"]
        for entry in entries {
            lines.append([formatter.string(from: entry.date), escape(entry.exerciseName), "\(entry.sets)",
                          "\(entry.reps)", entry.setRepsRaw, "\(entry.addedWeight)", escape(entry.note)].joined(separator: ";"))
        }
        return lines.joined(separator: "\n")
    }

    static func attempts(_ attempts: [MaxAttempt]) -> String {
        var lines = ["date;lift;added_kg;bodyweight_kg;competition;note"]
        for attempt in attempts {
            lines.append([formatter.string(from: attempt.date), attempt.lift.rawValue, "\(attempt.addedWeight)",
                          "\(attempt.bodyweight)", attempt.isCompetition ? "1" : "0", escape(attempt.note)].joined(separator: ";"))
        }
        return lines.joined(separator: "\n")
    }
}
