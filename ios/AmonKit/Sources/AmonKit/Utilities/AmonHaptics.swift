import UIKit

public enum AmonHaptics {
    public static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    public static func softImpact() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    public static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
