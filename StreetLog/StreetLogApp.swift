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
    @State private var tab = UserDefaults.standard.integer(forKey: "initialTab")

    var body: some View {
        TabView(selection: $tab) {
            DiaryView()
                .tabItem { Label("Дневник", systemImage: "calendar") }
                .tag(0)
            MasterView()
                .tabItem { Label("Мастер спорта", systemImage: "trophy") }
                .tag(1)
            AnalyticsView()
                .tabItem { Label("Аналитика", systemImage: "chart.bar.xaxis") }
                .tag(2)
            ProfileView()
                .tabItem { Label("Профиль", systemImage: "person.crop.circle") }
                .tag(3)
        }
        .onAppear {
            SeedData.seedIfNeeded(context)
            #if DEBUG
            DemoData.seedIfRequested(context)
            #endif
        }
    }
}
