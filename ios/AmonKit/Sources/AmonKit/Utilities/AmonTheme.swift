import SwiftUI
import UIKit

public enum AmonTheme {
    public static let accent: Color = Color(uiColor: accentUIColor)
    public static let canvas: Color = Color(uiColor: canvasUIColor)
    public static let surface: Color = Color(uiColor: surfaceUIColor)
    public static let elevatedSurface: Color = Color(uiColor: elevatedSurfaceUIColor)
    public static let pillSurface: Color = Color(uiColor: pillSurfaceUIColor)
    public static let border: Color = Color(uiColor: borderUIColor)
    public static let tabBarSurface: Color = Color(uiColor: tabBarSurfaceUIColor)
    public static let shadow: Color = Color(uiColor: shadowUIColor)

    private static let accentUIColor = UIColor { traitCollection in
        if traitCollection.userInterfaceStyle == .dark {
            return UIColor(red: 0.56, green: 0.69, blue: 0.88, alpha: 1)
        }
        return UIColor(red: 0.26, green: 0.36, blue: 0.55, alpha: 1)
    }

    private static let canvasUIColor = UIColor { traitCollection in
        if traitCollection.userInterfaceStyle == .dark {
            return UIColor(red: 0.06, green: 0.07, blue: 0.09, alpha: 1)
        }
        return UIColor(red: 0.95, green: 0.96, blue: 0.98, alpha: 1)
    }

    private static let surfaceUIColor = UIColor { traitCollection in
        if traitCollection.userInterfaceStyle == .dark {
            return UIColor(red: 0.12, green: 0.13, blue: 0.16, alpha: 1)
        }
        return UIColor.white
    }

    private static let elevatedSurfaceUIColor = UIColor { traitCollection in
        if traitCollection.userInterfaceStyle == .dark {
            return UIColor(red: 0.16, green: 0.18, blue: 0.22, alpha: 1)
        }
        return UIColor(red: 0.98, green: 0.98, blue: 0.99, alpha: 1)
    }

    private static let pillSurfaceUIColor = UIColor { traitCollection in
        if traitCollection.userInterfaceStyle == .dark {
            return UIColor(red: 0.18, green: 0.20, blue: 0.24, alpha: 1)
        }
        return UIColor(red: 0.93, green: 0.94, blue: 0.96, alpha: 1)
    }

    private static let borderUIColor = UIColor { traitCollection in
        if traitCollection.userInterfaceStyle == .dark {
            return UIColor.white.withAlphaComponent(0.1)
        }
        return UIColor.black.withAlphaComponent(0.08)
    }

    private static let tabBarSurfaceUIColor = UIColor { traitCollection in
        if traitCollection.userInterfaceStyle == .dark {
            return UIColor(red: 0.10, green: 0.11, blue: 0.14, alpha: 0.98)
        }
        return UIColor(red: 0.97, green: 0.97, blue: 0.98, alpha: 0.98)
    }

    private static let shadowUIColor = UIColor { traitCollection in
        if traitCollection.userInterfaceStyle == .dark {
            return UIColor.black.withAlphaComponent(0.34)
        }
        return UIColor.black.withAlphaComponent(0.08)
    }

    public static func applyGlobalAppearance() {
        configureNavigationBar()
    }

    private static func configureNavigationBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = elevatedSurfaceUIColor.withAlphaComponent(0.98)
        appearance.shadowColor = borderUIColor
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.label,
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor.label,
        ]

        let navigationBar = UINavigationBar.appearance()
        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.compactAppearance = appearance
        navigationBar.tintColor = accentUIColor
    }
}
