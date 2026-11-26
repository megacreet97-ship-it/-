import SwiftData
import SwiftUI

@main
struct StreetLogApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .fontDesign(.rounded)
                .tint(Theme.orange)
        }
        .modelContainer(for: [Exercise.self, WorkoutEntry.self, MaxAttempt.self, AthleteProfile.self, BodyMeasurement.self])
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @State private var tab = UserDefaults.standard.integer(forKey: "initialTab")
    #if DEBUG
    @State private var demoScreen = UserDefaults.standard.string(forKey: "demoScreen")
    #endif

    @Query private var profiles: [AthleteProfile]
    @Query private var attempts: [MaxAttempt]
    @Query(filter: #Predicate<WorkoutEntry> { $0.liftRaw != nil }) private var liftEntries: [WorkoutEntry]

    private var goal: Goal? {
        profiles.first?.effectiveGoal(hasStreetliftingData: !attempts.isEmpty || !liftEntries.isEmpty)
    }

    private var goalTabTitle: String {
        switch goal {
        case .ms: "Цель МС"
        case nil: "Цель"
        default: "Моя форма"
        }
    }

    var body: some View {
        TabView(selection: $tab) {
            DiaryView()
                .tabItem { Label("Дневник", systemImage: "calendar") }
                .tag(0)
            GoalView(goal: goal, openExercises: { tab = 2 })
                .tabItem { Label(goalTabTitle, systemImage: goal == .ms || goal == nil ? "trophy.fill" : "heart.fill") }
                .tag(1)
            ExercisesTabView()
                .tabItem { Label("Упражнения", systemImage: "figure.strengthtraining.traditional") }
                .tag(2)
            AnalyticsView()
                .tabItem { Label("Аналитика", systemImage: "chart.bar.xaxis") }
                .tag(3)
            ProfileView()
                .tabItem { Label("Профиль", systemImage: "person.crop.circle.fill") }
                .tag(4)
        }
        .onAppear {
            SeedData.seedIfNeeded(context)
            #if DEBUG
            DemoData.seedIfRequested(context)
            DemoData.applyGoalIfRequested(context)
            if UserDefaults.standard.bool(forKey: "demoRest") {
                RestTimer.shared.start(seconds: 95)
            }
            #endif
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            RestTimerBar(raised: false)
        }
        #if DEBUG
        .sheet(item: Binding(get: { demoScreen.map { DemoScreen(id: $0) } }, set: { demoScreen = $0?.id })) { screen in
            DemoScreenView(name: screen.id)
        }
        #endif
    }
}
