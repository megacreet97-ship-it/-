import UIKit

/// Short, soft taps for everyday actions. Prepared generators so the first tap is not delayed.
enum Haptics {
    private static let selection = UISelectionFeedbackGenerator()
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let light = UIImpactFeedbackGenerator(style: .light)

    static func select() {
        selection.selectionChanged()
        selection.prepare()
    }

    /// Adding a set, starting the rest timer.
    static func add() {
        soft.impactOccurred(intensity: 0.75)
        soft.prepare()
    }

    static func success() {
        light.impactOccurred(intensity: 0.55)
    }

    static func remove() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
