import AppKit
import SwiftUI

enum TicoBrand {
    static let displayName = "Tico"
    static let technicalName = "Tico"
    static let applicationSupportDirectoryName = "Tico"
    static let bundleIdentifier = "com.pedronazarito.Tico"
    static let userDefaultsPrefix = "com.tico."

    enum Appearance: CaseIterable {
        case light
        case dark
    }

    enum ColorToken: CaseIterable {
        case background
        case surface
        case primary
        case accent
        case text
        case secondaryText
    }

    struct RGB: Equatable {
        let red: UInt8
        let green: UInt8
        let blue: UInt8

        var hex: String {
            String(format: "#%02X%02X%02X", red, green, blue)
        }

        var nsColor: NSColor {
            NSColor(
                srgbRed: CGFloat(red) / 255,
                green: CGFloat(green) / 255,
                blue: CGFloat(blue) / 255,
                alpha: 1
            )
        }
    }

    enum Palette {
        static let background = adaptive(.background)
        static let surface = adaptive(.surface)
        static let primary = adaptive(.primary)
        static let accent = adaptive(.accent)
        static let text = adaptive(.text)
        static let secondaryText = adaptive(.secondaryText)

        static func rgb(_ token: ColorToken, appearance: Appearance) -> RGB {
            switch (appearance, token) {
            case (.light, .background): RGB(red: 0xF8, green: 0xF7, blue: 0xFC)
            case (.light, .surface): RGB(red: 0xFF, green: 0xFF, blue: 0xFF)
            case (.light, .primary): RGB(red: 0x63, green: 0x66, blue: 0xF1)
            case (.light, .accent): RGB(red: 0xFF, green: 0x6B, blue: 0x6B)
            case (.light, .text): RGB(red: 0x11, green: 0x18, blue: 0x27)
            case (.light, .secondaryText): RGB(red: 0x5B, green: 0x64, blue: 0x75)
            case (.dark, .background): RGB(red: 0x0B, green: 0x12, blue: 0x20)
            case (.dark, .surface): RGB(red: 0x15, green: 0x1E, blue: 0x2E)
            case (.dark, .primary): RGB(red: 0x7C, green: 0x8C, blue: 0xFF)
            case (.dark, .accent): RGB(red: 0xFF, green: 0x7A, blue: 0x72)
            case (.dark, .text): RGB(red: 0xF3, green: 0xF5, blue: 0xFA)
            case (.dark, .secondaryText): RGB(red: 0xAA, green: 0xB3, blue: 0xC2)
            }
        }

        private static func adaptive(_ token: ColorToken) -> Color {
            Color(
                nsColor: NSColor(name: nil) { appearance in
                    let brandAppearance: Appearance = appearance.bestMatch(
                        from: [.darkAqua, .aqua]
                    ) == .darkAqua ? .dark : .light
                    return rgb(token, appearance: brandAppearance).nsColor
                }
            )
        }
    }

    enum Assets {
        static let symbolLight = "TicoSymbolLight"
        static let symbolDark = "TicoSymbolDark"
        static let wordmarkLight = "TicoWordmarkLight"
        static let wordmarkDark = "TicoWordmarkDark"
        static let menuBarTemplate = "TicoMenuBarTemplate"
        static let appIcon = "Tico"

        static let menuBarImage: NSImage = {
            let image = resourceURL(named: menuBarTemplate, extension: "png")
                .flatMap(NSImage.init(contentsOf:))
                ?? NSImage(systemSymbolName: "bolt.circle", accessibilityDescription: displayName)
                ?? NSImage()
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = true
            return image
        }()

        static let bundle: Bundle = {
            if let resourceURL = Bundle.main.resourceURL,
               let packagedBundle = Bundle(
                   url: resourceURL.appendingPathComponent(
                       "Tico_Tico.bundle",
                       isDirectory: true
                   )
               ) {
                return packagedBundle
            }
            return Bundle.module
        }()

        static func symbolName(for appearance: Appearance) -> String {
            appearance == .dark ? symbolDark : symbolLight
        }

        static func wordmarkName(for appearance: Appearance) -> String {
            appearance == .dark ? wordmarkDark : wordmarkLight
        }

        static func resourceURL(named name: String, extension fileExtension: String) -> URL? {
            bundle.url(forResource: name, withExtension: fileExtension)
        }
    }
}
