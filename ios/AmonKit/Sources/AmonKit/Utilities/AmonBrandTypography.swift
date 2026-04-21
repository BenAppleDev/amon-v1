import CoreText
import SwiftUI

public enum AmonBrandTypography {
    public static let brandDisplayFontName = "EBGaramond-SemiBold"
    private static var hasRegisteredFonts = false
    private static let resourceBundle: Bundle = {
        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        return Bundle(for: BundleFinder.self)
        #endif
    }()

    public static func registerFontsIfNeeded() {
        guard !hasRegisteredFonts else { return }
        defer { hasRegisteredFonts = true }

        guard let url = resourceBundle.url(forResource: "EBGaramond", withExtension: "ttf", subdirectory: "Fonts")
            ?? resourceBundle.url(forResource: "EBGaramond", withExtension: "ttf")
        else {
            return
        }

        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }

    public static func brandDisplay(size: CGFloat, relativeTo textStyle: Font.TextStyle) -> Font {
        registerFontsIfNeeded()
        return .custom(brandDisplayFontName, size: size, relativeTo: textStyle)
    }
}

private final class BundleFinder {}
