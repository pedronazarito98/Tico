import SwiftUI
import XCTest
@testable import Tico

final class TicoBrandTests: XCTestCase {
    func testBrandIdentityUsesTicoAcrossPublicAndTechnicalNames() {
        XCTAssertEqual(TicoBrand.displayName, "Tico")
        XCTAssertEqual(TicoBrand.technicalName, "Tico")
        XCTAssertEqual(TicoBrand.applicationSupportDirectoryName, "Tico")
        XCTAssertEqual(TicoBrand.bundleIdentifier, "com.pedronazarito.Tico")
        XCTAssertEqual(TicoBrand.userDefaultsPrefix, "com.tico.")
    }

    func testApprovedPaletteHexValuesAreStable() {
        let light: [TicoBrand.ColorToken: String] = [
            .background: "#F8F7FC",
            .surface: "#FFFFFF",
            .primary: "#6366F1",
            .accent: "#FF6B6B",
            .text: "#111827",
            .secondaryText: "#5B6475"
        ]
        let dark: [TicoBrand.ColorToken: String] = [
            .background: "#0B1220",
            .surface: "#151E2E",
            .primary: "#7C8CFF",
            .accent: "#FF7A72",
            .text: "#F3F5FA",
            .secondaryText: "#AAB3C2"
        ]

        for token in TicoBrand.ColorToken.allCases {
            XCTAssertEqual(TicoBrand.Palette.rgb(token, appearance: .light).hex, light[token])
            XCTAssertEqual(TicoBrand.Palette.rgb(token, appearance: .dark).hex, dark[token])
        }
    }

    func testAdaptiveAssetsUseTheApprovedAppearanceVariants() {
        XCTAssertEqual(TicoBrand.Assets.symbolName(for: .light), "TicoSymbolLight")
        XCTAssertEqual(TicoBrand.Assets.symbolName(for: .dark), "TicoSymbolDark")
        XCTAssertEqual(TicoBrand.Assets.wordmarkName(for: .light), "TicoWordmarkLight")
        XCTAssertEqual(TicoBrand.Assets.wordmarkName(for: .dark), "TicoWordmarkDark")
    }

    func testTextTokensMeetNormalTextContrastAgainstBrandBackgrounds() {
        for appearance in TicoBrand.Appearance.allCases {
            let background = TicoBrand.Palette.rgb(.background, appearance: appearance)
            let text = TicoBrand.Palette.rgb(.text, appearance: appearance)
            let secondaryText = TicoBrand.Palette.rgb(.secondaryText, appearance: appearance)

            XCTAssertGreaterThanOrEqual(contrastRatio(text, background), 4.5)
            XCTAssertGreaterThanOrEqual(contrastRatio(secondaryText, background), 4.5)
        }
    }

    func testEveryRuntimeBrandAssetIsBundled() {
        let pngNames = [
            TicoBrand.Assets.symbolLight,
            TicoBrand.Assets.symbolDark,
            TicoBrand.Assets.wordmarkLight,
            TicoBrand.Assets.wordmarkDark,
            TicoBrand.Assets.menuBarTemplate
        ]

        for name in pngNames {
            XCTAssertNotNil(
                TicoBrand.Assets.resourceURL(named: name, extension: "png"),
                "Missing runtime asset \(name).png"
            )
        }
        XCTAssertNotNil(
            TicoBrand.Assets.resourceURL(named: TicoBrand.Assets.appIcon, extension: "icns")
        )
    }

    func testMenuBarImageIsAVisibleTemplateAtTheExpectedSize() {
        let image = TicoBrand.Assets.menuBarImage

        XCTAssertTrue(image.isTemplate)
        XCTAssertEqual(image.size, NSSize(width: 18, height: 18))
        XCTAssertFalse(image.representations.isEmpty)
    }

    @MainActor
    func testWordmarkComponentRendersInLightAndDarkAppearances() {
        for colorScheme in [ColorScheme.light, .dark] {
            let renderer = ImageRenderer(
                content: TicoMarkView(.wordmark)
                    .environment(\.colorScheme, colorScheme)
                    .frame(width: 142, height: 44)
            )
            renderer.scale = 2
            XCTAssertNotNil(renderer.nsImage)
        }
    }

    private func contrastRatio(_ foreground: TicoBrand.RGB, _ background: TicoBrand.RGB) -> Double {
        let lighter = max(relativeLuminance(foreground), relativeLuminance(background))
        let darker = min(relativeLuminance(foreground), relativeLuminance(background))
        return (lighter + 0.05) / (darker + 0.05)
    }

    private func relativeLuminance(_ color: TicoBrand.RGB) -> Double {
        func linearize(_ component: UInt8) -> Double {
            let value = Double(component) / 255
            return value <= 0.04045
                ? value / 12.92
                : pow((value + 0.055) / 1.055, 2.4)
        }

        return 0.2126 * linearize(color.red)
            + 0.7152 * linearize(color.green)
            + 0.0722 * linearize(color.blue)
    }
}
