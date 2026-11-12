import SwiftUI
import CoreText

enum FontLoader {
    private static var didLoad = false

    static func register() {
        guard !didLoad else { return }
        didLoad = true
        let names = ["SpaceGrotesk", "IBMPlexMono-Regular", "IBMPlexMono-Medium", "Inter"]
        for name in names {
            guard let url = Bundle.module.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts")
                ?? Bundle.module.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
