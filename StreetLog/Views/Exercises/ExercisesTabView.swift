import SwiftData
import SwiftUI

extension VolumeZone {
    var color: Color {
        switch self {
        case .none: Color(.systemGray)
        case .low: Theme.pink
        case .maintain: Theme.yellow
        case .grow: Theme.green
        case .high: Theme.violet
        }
    }
}

struct RatingStars: View {
    let rating: Int
    var size: Font = .caption2

    var body: some View {
        HStack(spacing: 1) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: index <= rating ? "star.fill" : "star")
                    .foregroundStyle(index <= rating ? Theme.yellow : Color.white.opacity(0.2))
            }
        }
        .font(size)
        .accessibilityLabel("Оценка \(rating) из 5")
    }
}

struct ExercisesTabView: View {
    enum Pane: String, CaseIterable { case muscles = "Мышцы", library = "Справочник", progress = "Прогресс" }

    @Query(sort: \WorkoutEntry.date) private var entries: [WorkoutEntry]
    @Query private var exercises: [Exercise]
    @State private var section = Pane.muscles
    @State private var muscle: Muscle?
    @State private var lastFourWeeks = false

    private let calendar = Calendar.current

    private var lookup: (String) -> ExerciseInfo? {
        let byName = Dictionary(exercises.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        return { name in ExerciseInfo.lookup(name, category: byName[name]?.category, lift: byName[name]?.lift) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SegmentedCapsules(items: Pane.allCases, selection: $section) { $0.rawValue }
                    switch section {
                    case .muscles: musclesSection
                    case .library: ExerciseLibraryList(muscle: $muscle, lookup: lookup, entries: entries, exercises: exercises)
                    case .progress: progressSection
                    }
                }
                .padding()
            }
            .scrollIndicators(.hidden)
            .background(Color(.systemBackground))
            .navigationTitle("Упражнения")
            .navigationDestination(for: String.self) { name in
                ExerciseDetailView(exerciseName: name)
            }
        }
    }

    // MARK: Muscles

    private var weeklySets: [Muscle: Double] {
        let days = lastFourWeeks ? 28 : 7
        let from = calendar.date(byAdding: .day, value: -days + 1, to: calendar.startOfDay(for: .now)) ?? .now
        let raw = MuscleAnalytics.sets(entries.filter { $0.date >= from }.map(\.logItem), lookup: lookup)
        return raw.mapValues { $0 / Double(days / 7) }
    }

    @ViewBuilder
    private var musclesSection: some View {
        let sets = weeklySets
        Picker("Период", selection: $lastFourWeeks) {
            Text("Эта неделя").tag(false)
            Text("В среднем за 4 нед").tag(true)
        }
        .pickerStyle(.segmented)
        Text("Рабочие подходы в неделю на каждую мышцу: если мышца главная в упражнении — подход целиком, если помогает — половина. Для роста обычно нужно 10–20 подходов.")
            .font(.footnote).foregroundStyle(.secondary)
        HStack(spacing: 10) {
            ForEach([VolumeZone.low, .maintain, .grow, .high], id: \.self) { zone in
                HStack(spacing: 4) {
                    Circle().fill(zone.color).frame(width: 7, height: 7)
                    Text("\(zone.title) \(zone.range)")
                }
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)

        ForEach(Muscle.groups, id: \.title) { group in
            Card(title: group.title) {
                ForEach(group.muscles) { muscle in
                    muscleRow(muscle, sets: sets[muscle] ?? 0)
                }
            }
        }
        if (sets[.cardio] ?? 0) > 0 {
            Text("Кардио: \(Format.number(((sets[.cardio] ?? 0) * 10).rounded() / 10)) занятий в неделю.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        let weak = Muscle.key.filter { (sets[$0] ?? 0) < 4 }
        if !weak.isEmpty {
            Card(title: "Что добавить", systemImage: "sparkles") {
                Text("Этим мышцам не хватает нагрузки. Лучшие упражнения для них:")
                    .font(.footnote).foregroundStyle(.secondary)
                ForEach(weak) { muscle in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(muscle.title).font(.subheadline.weight(.bold))
                        ForEach(MuscleAnalytics.best(for: muscle, limit: 2), id: \.name) { item in
                            NavigationLink(value: item.name) {
                                HStack {
                                    Text(item.name).font(.footnote).foregroundStyle(.primary).multilineTextAlignment(.leading)
                                    Spacer()
                                    RatingStars(rating: item.info.rating)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func muscleRow(_ muscle: Muscle, sets: Double) -> some View {
        let zone = VolumeZone(sets: sets)
        return Button {
            self.muscle = muscle
            withAnimation(.snappy) { section = .library }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(muscle.title).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                    Spacer()
                    Text(zone.title).font(.caption.weight(.bold)).foregroundStyle(zone.color)
                    Text(Format.number((sets * 10).rounded() / 10)).font(.subheadline.weight(.bold)).monospacedDigit()
                        .frame(minWidth: 28, alignment: .trailing)
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                }
                ProgressBar(fraction: sets / 24, tint: zone.color, height: 6)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Progress

    @ViewBuilder
    private var progressSection: some View {
        let items = entries.map(\.logItem)
        let progress = MuscleAnalytics.progress(items)
        let records = MuscleAnalytics.personalRecords(items, since: calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: .now)) ?? .now)
        HStack(spacing: 12) {
            Card { StatTile(title: "Рекорды", value: "\(records)", caption: "за 30 дней", tint: Theme.yellow) }
            Card { StatTile(title: "Растут", value: "\(progress.filter { $0.change > 0.005 }.count) из \(progress.count)", caption: "упражнений", tint: Theme.green) }
        }
        Text("Лучший результат последних 4 недель против 4 недель до них. С отягощением — расчётный максимум на 1 раз, без веса — повторения в лучшем подходе.")
            .font(.footnote).foregroundStyle(.secondary)
        if progress.isEmpty {
            Card {
                Text("Нужны записи хотя бы за 5 недель по одним и тем же упражнениям — тогда здесь появится сравнение.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        } else {
            Card(title: "По упражнениям", systemImage: "chart.bar") {
                ForEach(progress) { row in
                    NavigationLink(value: row.name) { progressRow(row) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private func progressRow(_ row: ExerciseProgress) -> some View {
        let tint = row.change > 0.005 ? Theme.green : row.change < -0.005 ? Theme.pink : Color.secondary
        let format: (Double) -> String = { row.weighted ? Format.kg(($0 * 10).rounded() / 10) : "\(Int($0.rounded())) раз" }
        let percent = (row.change * 1000).rounded() / 10
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary).multilineTextAlignment(.leading)
                Text("\(format(row.before)) → \(format(row.now))").font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            Spacer()
            Pill(text: (percent > 0 ? "+" : "") + Format.number(percent) + "%", tint: tint)
        }
        .contentShape(Rectangle())
    }
}

struct ExerciseLibraryList: View {
    @Binding var muscle: Muscle?
    let lookup: (String) -> ExerciseInfo?
    let entries: [WorkoutEntry]
    let exercises: [Exercise]
    @State private var query = ""

    private var timesDone: [String: Int] {
        entries.reduce(into: [:]) { $0[$1.exerciseName, default: 0] += 1 }
    }

    private var rows: [(exercise: Exercise, info: ExerciseInfo?)] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return exercises
            .map { (exercise: $0, info: lookup($0.name)) }
            .filter { row in
                (q.isEmpty || row.exercise.name.lowercased().contains(q))
                    && (muscle.map { row.info?.primary.contains($0) ?? false } ?? true)
            }
    }

    var body: some View {
        let rows = rows
        let done = timesDone
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Поиск упражнения", text: $query)
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
            }
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                chip("Все мышцы", selected: muscle == nil) { muscle = nil }
                ForEach(Muscle.allCases) { item in
                    chip(item.title, selected: muscle == item) { muscle = item }
                }
            }
            .padding(.horizontal)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -16)

        if let muscle {
            SectionTitle(title: "Лучшие на «\(muscle.title.lowercased())»", trailing: "\(rows.count)")
            let sorted = rows.sorted { lhs, rhs in
                let l = lhs.info, r = rhs.info
                if (l?.rating ?? 0) != (r?.rating ?? 0) { return (l?.rating ?? 0) > (r?.rating ?? 0) }
                if (l?.primary.count ?? 0) != (r?.primary.count ?? 0) { return (l?.primary.count ?? 0) < (r?.primary.count ?? 0) }
                return lhs.exercise.name < rhs.exercise.name
            }
            listCard(sorted, done: done)
            Text("Звёзды — экспертная оценка того, насколько хорошо упражнение нагружает мышцу: большая амплитуда, нагрузка в растянутом положении, возможность прибавлять вес. Лучшее упражнение — то, которое вы делаете регулярно и с прогрессом.")
                .font(.caption).foregroundStyle(.secondary)
        } else {
            let categories = Array(Set(rows.map(\.exercise.category))).sorted(by: ExerciseLibrary.areInOrder)
            ForEach(categories, id: \.self) { category in
                VStack(alignment: .leading, spacing: 8) {
                    Text(category.uppercased()).font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.horizontal, 4)
                    listCard(rows.filter { $0.exercise.category == category }.sorted { $0.exercise.name < $1.exercise.name }, done: done)
                }
            }
        }
        if rows.isEmpty {
            Text("Ничего не найдено").foregroundStyle(.secondary).frame(maxWidth: .infinity)
        }
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: { withAnimation(.snappy, action) }) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(selected ? Color.white : Color.secondary)
                .background(selected ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Theme.card), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func listCard(_ items: [(exercise: Exercise, info: ExerciseInfo?)], done: [String: Int]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, row in
                if index > 0 { Divider().padding(.leading, 70) }
                NavigationLink(value: row.exercise.name) {
                    HStack(alignment: .center, spacing: 12) {
                        ExerciseThumbnail(photo: row.info?.photo)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(row.exercise.name).font(.subheadline).foregroundStyle(.primary).multilineTextAlignment(.leading)
                            Text(subtitle(row, done: done)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 8)
                        if let rating = row.info?.rating, rating > 0 { RatingStars(rating: rating) }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func subtitle(_ row: (exercise: Exercise, info: ExerciseInfo?), done: [String: Int]) -> String {
        let muscles = row.info.map { $0.primary.map(\.title).joined(separator: ", ") } ?? "нет данных"
        guard let times = done[row.exercise.name] else { return muscles }
        return muscles + " · делали \(times) раз"
    }
}

/// Reference card shown on top of an exercise's statistics.
struct ExerciseInfoSection: View {
    let name: String
    let info: ExerciseInfo

    var body: some View {
        Section("Техника") {
            if let photo = info.photo {
                TechniquePhotos(name: name, photo: photo)
                    .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
            }
            Link(destination: TechniquePhotos.videoSearchURL(for: name)) {
                Label("Видео техники на YouTube", systemImage: "play.rectangle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.orange)
            }
        }
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Основная нагрузка").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if info.rating > 0 { RatingStars(rating: info.rating, size: .footnote) }
                }
                FlowPills(items: info.primary.map(\.title), tint: Theme.orange)
                if !info.secondary.isEmpty {
                    Text("Помогают").font(.caption).foregroundStyle(.secondary)
                    FlowPills(items: info.secondary.map(\.title), tint: .secondary)
                }
                Text([info.kind.title, info.levelTitle, info.equipment].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
                if !info.tip.isEmpty { Text(info.tip).font(.subheadline) }
                if info.rating == 0 {
                    Text("Своё упражнение: мышцы определены по группе, оценки нет.").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
            if let main = info.primary.first, info.rating > 0 {
                ForEach(MuscleAnalytics.best(for: main, limit: 4).filter { $0.name != name }.prefix(3), id: \.name) { item in
                    NavigationLink(value: item.name) {
                        HStack {
                            Text(item.name).font(.subheadline)
                            Spacer()
                            RatingStars(rating: item.info.rating)
                        }
                    }
                }
            }
        } header: {
            Text("Справка")
        } footer: {
            if let main = info.primary.first, info.rating > 0 {
                Text("Ниже справки — лучшие упражнения на «\(main.title.lowercased())».")
            }
        }
    }
}

/// Wrapping row of pills.
struct FlowPills: View {
    let items: [String]
    var tint: Color

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { pills }
            VStack(alignment: .leading, spacing: 6) { pills }
        }
    }

    private var pills: some View {
        ForEach(items, id: \.self) { Pill(text: $0, tint: tint) }
    }
}

extension ExerciseInfo {
    static func photo(_ stem: String, frame: Int) -> UIImage? {
        UIImage(named: "\(stem)-\(frame).jpg")
    }
}

struct ExerciseThumbnail: View {
    let photo: String?

    var body: some View {
        Group {
            if let photo, let image = ExerciseInfo.photo(photo, frame: 1) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Theme.elevated
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// Start and end positions from free-exercise-db, alternating like a slow animation.
struct TechniquePhotos: View {
    let name: String
    let photo: String

    @State private var playing = true
    @State private var manualFrame = 0

    static func videoSearchURL(for name: String) -> URL {
        let clean = name.replacingOccurrences(of: #"\s*\((сек|мин)\)"#, with: "", options: .regularExpression)
        var components = URLComponents(string: "https://www.youtube.com/results")!
        components.queryItems = [URLQueryItem(name: "search_query", value: "\(clean) техника выполнения")]
        return components.url!
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TimelineView(.periodic(from: .now, by: 1.3)) { context in
                let frame = playing ? Int(context.date.timeIntervalSinceReferenceDate / 1.3) % 2 : manualFrame
                ZStack(alignment: .bottomLeading) {
                    ForEach(0..<2, id: \.self) { index in
                        if let image = ExerciseInfo.photo(photo, frame: index) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .opacity(frame == index ? 1 : 0)
                        }
                    }
                    Text(frame == 0 ? "1 · Старт" : "2 · Финиш")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.65), in: Capsule())
                        .foregroundStyle(.white)
                        .padding(10)
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(4 / 3, contentMode: .fit)
                .background(Theme.elevated)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .animation(.easeInOut(duration: 0.35), value: frame)
                .onTapGesture {
                    manualFrame = frame
                    playing.toggle()
                }
            }
            HStack(spacing: 8) {
                ForEach(0..<2, id: \.self) { index in
                    Button {
                        playing = false
                        manualFrame = index
                    } label: {
                        HStack(spacing: 8) {
                            if let image = ExerciseInfo.photo(photo, frame: index) {
                                Image(uiImage: image).resizable().scaledToFill()
                                    .frame(width: 48, height: 36)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            Text(index == 0 ? "Старт" : "Финиш").font(.footnote.weight(.semibold))
                            Spacer(minLength: 0)
                        }
                        .padding(6)
                        .background(Theme.elevated, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(!playing && manualFrame == index ? Theme.orange : .clear, lineWidth: 2)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("Нажмите на фото, чтобы остановить. Фото: free-exercise-db (общественное достояние) — оборудование может немного отличаться.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
