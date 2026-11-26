import SwiftData
import SwiftUI

@main
struct StreetLogApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [Exercise.self, WorkoutEntry.self, MaxAttempt.self, AthleteProfile.self])
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var context

    var body: some View {
        TabView {
            DiaryView()
                .tabItem { Label("Дневник", systemImage: "calendar") }
            MasterView()
                .tabItem { Label("Мастер спорта", systemImage: "trophy") }
            AnalyticsView()
                .tabItem { Label("Аналитика", systemImage: "chart.bar.xaxis") }
            ProfileView()
                .tabItem { Label("Профиль", systemImage: "person.crop.circle") }
        }
        .task { SeedData.seedIfNeeded(context) }
    }
}
