import Foundation

enum Federation: String, CaseIterable, Identifiable, Codable {
    case isf
    case wsf

    var id: String { rawValue }

    var title: String {
        switch self {
        case .isf: "ISF-Россия"
        case .wsf: "WSF"
        }
    }

    var source: String {
        switch self {
        case .isf: "Нормативы ISF-Россия, классический стритлифтинг, мужчины, действуют с 01.01.2025 (streetlifting.ru)"
        case .wsf: "Нормативы WSF 2025, мужчины, дивизион с допинг-контролем (по таблице региональной федерации WSF)"
        }
    }
}

enum SportRank: String, CaseIterable, Identifiable, Codable, Comparable {
    case kms
    case ms
    case msmk

    var id: String { rawValue }

    var title: String {
        switch self {
        case .kms: "КМС"
        case .ms: "МС"
        case .msmk: "МСМК"
        }
    }

    private var order: Int {
        switch self {
        case .kms: 0
        case .ms: 1
        case .msmk: 2
        }
    }

    static func < (lhs: SportRank, rhs: SportRank) -> Bool { lhs.order < rhs.order }
}

struct LiftNorms: Equatable {
    let pullUp: Double
    let dip: Double
    let total: Double

    func value(for lift: Lift) -> Double {
        switch lift {
        case .pullUp: pullUp
        case .dip: dip
        }
    }
}

struct WeightClassStandard: Identifiable, Equatable {
    let federation: Federation
    /// Upper bodyweight limit of the class, kg.
    let limit: Double
    /// Upper limit of the previous class (lower bound of this one), kg.
    let lowerLimit: Double
    let norms: [SportRank: LiftNorms]

    var id: String { "\(federation.rawValue)-\(limit)" }
    var title: String { "до \(Format.number(limit)) кг" }

    func norms(for rank: SportRank) -> LiftNorms? { norms[rank] }

    /// Highest rank whose total norm is met.
    func achievedRank(total: Double) -> SportRank? {
        SportRank.allCases.reversed().first { rank in
            guard let norm = norms[rank] else { return false }
            return total >= norm.total
        }
    }

    func contains(bodyweight: Double) -> Bool {
        bodyweight > lowerLimit && bodyweight <= limit
    }
}

enum Standards {
    /// Men's classic streetlifting. Single-lift columns are the norms for the separate single-lift disciplines;
    /// in the biathlon (двоеборье) the rank is awarded by the total.
    static let all: [WeightClassStandard] = [
        WeightClassStandard(federation: .isf, limit: 67.5, lowerLimit: 60, norms: [
            .kms: LiftNorms(pullUp: 60, dip: 85, total: 135),
            .ms: LiftNorms(pullUp: 67.5, dip: 100, total: 152.5),
            .msmk: LiftNorms(pullUp: 77.5, dip: 112.5, total: 180),
        ]),
        WeightClassStandard(federation: .isf, limit: 75, lowerLimit: 67.5, norms: [
            .kms: LiftNorms(pullUp: 65, dip: 90, total: 145),
            .ms: LiftNorms(pullUp: 72.5, dip: 105, total: 165),
            .msmk: LiftNorms(pullUp: 82.5, dip: 117.5, total: 190),
        ]),
        WeightClassStandard(federation: .wsf, limit: 67.5, lowerLimit: 60, norms: [
            .kms: LiftNorms(pullUp: 55, dip: 77.5, total: 122.5),
            .ms: LiftNorms(pullUp: 62.5, dip: 90, total: 140),
            .msmk: LiftNorms(pullUp: 72.5, dip: 107.5, total: 170),
        ]),
        WeightClassStandard(federation: .wsf, limit: 75, lowerLimit: 67.5, norms: [
            .kms: LiftNorms(pullUp: 60, dip: 82.5, total: 132.5),
            .ms: LiftNorms(pullUp: 67.5, dip: 95, total: 152.5),
            .msmk: LiftNorms(pullUp: 77.5, dip: 112.5, total: 180),
        ]),
    ]

    static func classes(for federation: Federation) -> [WeightClassStandard] {
        all.filter { $0.federation == federation }.sorted { $0.limit < $1.limit }
    }

    static func lookup(federation: Federation, limit: Double) -> WeightClassStandard? {
        all.first { $0.federation == federation && $0.limit == limit }
    }

    /// The class the athlete would compete in at the given bodyweight, if it is one of the supported classes.
    static func classFor(bodyweight: Double, federation: Federation) -> WeightClassStandard? {
        classes(for: federation).first { $0.contains(bodyweight: bodyweight) }
    }

    /// Splits a total norm into per-lift targets proportionally to the single-lift norms, on a 1.25 kg step.
    static func split(_ norms: LiftNorms, step: Double = AttemptPlanner.defaultStep) -> (pullUp: Double, dip: Double) {
        let singleSum = norms.pullUp + norms.dip
        guard singleSum > 0 else { return (0, 0) }
        let pull = AttemptPlanner.round(norms.total * norms.pullUp / singleSum, step: step)
        return (pull, norms.total - pull)
    }
}
