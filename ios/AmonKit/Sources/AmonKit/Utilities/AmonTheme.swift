import SwiftUI
import UIKit

public enum AmonTheme {
    public static let accent = Color(uiColor: accentUIColor)
    public static let danger = Color(uiColor: dangerUIColor)
    public static let canvas = Color(uiColor: canvasUIColor)
    public static let softCanvas = Color(uiColor: softCanvasUIColor)
    public static let elevatedSurface = Color(uiColor: elevatedSurfaceUIColor)
    public static let surface = Color(uiColor: surfaceUIColor)
    public static let pillSurface = Color(uiColor: pillSurfaceUIColor)
    public static let border = Color(uiColor: borderUIColor)
    public static let strongBorder = Color(uiColor: strongBorderUIColor)
    public static let ink = Color(uiColor: inkUIColor)
    public static let muted = Color(uiColor: mutedUIColor)
    public static let tabBarSurface = Color(uiColor: tabBarSurfaceUIColor)
    public static let shadow = Color(uiColor: shadowUIColor)

    public static let accentUIColor = UIColor(hex: 0xC6FF61)
    public static let dangerUIColor = UIColor(hex: 0xFF5E4F)
    public static let canvasUIColor = UIColor(hex: 0x060606)
    public static let softCanvasUIColor = UIColor(hex: 0x0C0C0C)
    public static let elevatedSurfaceUIColor = UIColor(hex: 0x121212)
    public static let surfaceUIColor = UIColor.white.withAlphaComponent(0.035)
    public static let pillSurfaceUIColor = UIColor.white.withAlphaComponent(0.06)
    public static let borderUIColor = UIColor.white.withAlphaComponent(0.12)
    public static let strongBorderUIColor = UIColor.white.withAlphaComponent(0.22)
    public static let inkUIColor = UIColor(hex: 0xF4EFE8)
    public static let mutedUIColor = UIColor(hex: 0x9F988F)
    public static let tabBarSurfaceUIColor = UIColor(hex: 0x0C0C0C).withAlphaComponent(0.96)
    public static let shadowUIColor = UIColor.black.withAlphaComponent(0.34)

    public static func applyGlobalAppearance() {
        AmonBrandTypography.registerFontsIfNeeded()
        configureNavigationBar()
    }

    private static func configureNavigationBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = softCanvasUIColor
        appearance.shadowColor = borderUIColor
        appearance.titleTextAttributes = [
            .foregroundColor: inkUIColor,
            .font: UIFont(name: AmonBrandTypography.brandDisplayFontName, size: 19)
                ?? .systemFont(ofSize: 19, weight: .semibold),
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: inkUIColor,
            .font: UIFont(name: AmonBrandTypography.brandDisplayFontName, size: 32)
                ?? .systemFont(ofSize: 32, weight: .semibold),
        ]

        let navigationBar = UINavigationBar.appearance()
        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.compactAppearance = appearance
        navigationBar.tintColor = accentUIColor
    }
}

private extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        let red = CGFloat((hex & 0xFF0000) >> 16) / 255
        let green = CGFloat((hex & 0x00FF00) >> 8) / 255
        let blue = CGFloat(hex & 0x0000FF) / 255
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}
