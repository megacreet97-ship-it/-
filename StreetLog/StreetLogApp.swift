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
        .modelContainer(for: [Exercise.self, WorkoutEntry.self, MaxAttempt.self, AthleteProfile.self])
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @State private var tab = UserDefaults.standard.integer(forKey: "initialTab")
    #if DEBUG
    @State private var demoScreen = UserDefaults.standard.string(forKey: "demoScreen")
    #endif

    var body: some View {
        TabView(selection: $tab) {
            DiaryView()
                .tabItem { Label("Дневник", systemImage: "calendar") }
                .tag(0)
            MasterView()
                .tabItem { Label("Мастер спорта", systemImage: "trophy.fill") }
                .tag(1)
            AnalyticsView()
                .tabItem { Label("Аналитика", systemImage: "chart.bar.xaxis") }
                .tag(2)
            ProfileView()
                .tabItem { Label("Профиль", systemImage: "person.crop.circle.fill") }
                .tag(3)
        }
        .onAppear {
            SeedData.seedIfNeeded(context)
            #if DEBUG
            DemoData.seedIfRequested(context)
            #endif
        }
        #if DEBUG
        .sheet(item: Binding(get: { demoScreen.map { DemoScreen(id: $0) } }, set: { demoScreen = $0?.id })) { screen in
            DemoScreenView(name: screen.id)
        }
        #endif
    }
}
