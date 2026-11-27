import SwiftUI

/// Sits in the tab's bottom safe area, so it stays above the tab bar (and, in the diary, above the add button).
struct RestTimerInset: ViewModifier {
    @ObservedObject private var timer = RestTimer.shared

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            if timer.endsAt != nil || timer.finishedAt != nil {
                RestTimerBar()
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
        }
    }
}

extension View {
    func restTimerInset() -> some View { modifier(RestTimerInset()) }
}

struct RestTimerBar: View {
    @ObservedObject private var timer = RestTimer.shared
    @State private var showingSettings = false

    var body: some View {
        Group {
            if timer.endsAt != nil {
                bar(done: false)
            } else if timer.finishedAt != nil {
                bar(done: true)
            }
        }
        .sheet(isPresented: $showingSettings) { RestTimerSheet() }
    }

    private func bar(done: Bool) -> some View {
        HStack(spacing: 6) {
            Button { showingSettings = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: done ? "bolt.fill" : "timer")
                    if done {
                        Text("Отдых окончен").font(.subheadline.weight(.bold)).lineLimit(1)
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Отдых").font(.caption2).foregroundStyle(.white.opacity(0.8))
                            Text(RestTimer.format(timer.remaining))
                                .font(.title3.weight(.bold).monospacedDigit())
                                .contentTransition(.numericText())
                        }
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 8)
            }
            .buttonStyle(.plain)
            if done {
                Button("Ещё \(RestTimer.format(timer.duration))") { timer.start(seconds: Int(timer.duration)) }
                    .buttonStyle(RestChipStyle())
            } else {
                Button("−15") { timer.add(-15) }.buttonStyle(RestChipStyle()).accessibilityLabel("Убавить 15 секунд")
                Button("+15") { timer.add(15) }.buttonStyle(RestChipStyle()).accessibilityLabel("Добавить 15 секунд")
                Button { timer.stop() } label: { Image(systemName: "xmark") }
                    .buttonStyle(RestChipStyle())
                    .accessibilityLabel("Остановить таймер")
            }
        }
        .padding(6)
        .background {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(done ? Theme.green : Color(white: 0.23))
                if !done {
                    GeometryReader { geo in
                        Theme.accentGradient.opacity(0.55)
                            .frame(width: geo.size.width * timer.progress)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.45), radius: 12, y: 6)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(done ? "Отдых окончен" : "Отдых \(RestTimer.format(timer.remaining))")
    }
}

struct RestTimerSheet: View {
    @ObservedObject private var timer = RestTimer.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Выберите время один раз. Кнопка с часами в дневнике будет запускать его сразу, заходить сюда снова не нужно.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(RestTimer.presets, id: \.self) { seconds in
                            Button {
                                timer.setDefault(seconds)
                                Haptics.select()
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(RestTimer.format(TimeInterval(seconds)))
                                        .font(.title.weight(.bold).monospacedDigit())
                                    Text(RestTimer.caption(seconds))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(timer.defaultSeconds == seconds ? Theme.orange : .clear, lineWidth: 2)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Запускать после подхода").font(.subheadline.weight(.semibold))
                            Text("После «+ подход» и сохранения записи").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("Запускать после подхода", isOn: Binding(get: { timer.autoStart }, set: timer.setAutoStart))
                            .labelsHidden()
                            .tint(Theme.green)
                    }
                    .padding(14)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    Text("Для силы и стритлифтинга отдыхают 3–5 минут, для мышечной массы 1,5–2 минуты, для выносливости около минуты. По окончании телефон вибрирует и звучит сигнал — держите приложение открытым и звук включённым.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if timer.endsAt != nil {
                        Button(role: .destructive) { timer.stop(); dismiss() } label: {
                            Text("Остановить таймер").frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemBackground))
            .navigationTitle("Таймер отдыха")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } }
            }
        }
    }
}

private struct RestChipStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .frame(minWidth: 44, minHeight: 38)
            .padding(.horizontal, 8)
            .background(.black.opacity(configuration.isPressed ? 0.45 : 0.28), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
