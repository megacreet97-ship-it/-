import SwiftUI

struct StandardsView: View {
    let initialFederation: Federation
    let total: Double
    let pullUp: Double
    let dip: Double

    @State private var federation: Federation = .isf
    @State private var didSetInitial = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SegmentedCapsules(items: Federation.allCases, selection: $federation) { $0.title }

                ForEach(Standards.classes(for: federation)) { standard in
                    Card(title: standard.title, systemImage: "scalemass.fill") {
                        Grid(alignment: .trailing, horizontalSpacing: 12, verticalSpacing: 10) {
                            GridRow {
                                Text("").gridColumnAlignment(.leading)
                                header("Подтяг.")
                                header("Брусья")
                                header("Сумма")
                            }
                            Divider().overlay(Color.white.opacity(0.08)).gridCellUnsizedAxes(.horizontal)
                            ForEach(SportRank.allCases) { rank in
                                if let norms = standard.norms(for: rank) {
                                    GridRow {
                                        Text(rank.title)
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(rank.color)
                                            .gridColumnAlignment(.leading)
                                        cell(norms.pullUp, done: pullUp >= norms.pullUp)
                                        cell(norms.dip, done: dip >= norms.dip)
                                        cell(norms.total, done: total >= norms.total, emphasized: true)
                                    }
                                }
                            }
                            Divider().overlay(Color.white.opacity(0.08)).gridCellUnsizedAxes(.horizontal)
                            GridRow {
                                Text("Вы").font(.subheadline.weight(.bold)).gridColumnAlignment(.leading)
                                mine(pullUp)
                                mine(dip)
                                mine(total)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("Как читать таблицу", systemImage: "info.circle")
                        .font(.subheadline.weight(.semibold))
                    Text("В двоеборье звание присваивается по сумме. Колонки «Подтяг.» и «Брусья» — нормативы для отдельных дисциплин (подтягивания или брусья на максимум). Зелёным отмечено то, что вы уже выполнили.")
                    Text("Стритлифтинг не входит в ЕВСК — звания присваивают федерации. Источник: \(federation.source). Перед стартом сверьтесь с актуальным положением турнира.")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(16)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .navigationTitle("Нормативы")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !didSetInitial {
                federation = initialFederation
                didSetInitial = true
            }
        }
    }

    private func header(_ text: String) -> some View {
        Text(text).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
    }

    private func cell(_ value: Double, done: Bool, emphasized: Bool = false) -> some View {
        HStack(spacing: 3) {
            if done { Image(systemName: "checkmark").font(.caption2.weight(.bold)) }
            Text(Format.number(value))
        }
        .font(emphasized ? .subheadline.weight(.bold) : .subheadline)
        .monospacedDigit()
        .foregroundStyle(done ? Theme.green : Color.primary)
    }

    private func mine(_ value: Double) -> some View {
        Text(Format.number(value))
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(Theme.accentGradient)
    }
}
