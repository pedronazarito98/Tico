import AppKit
import SwiftUI

/// Fronteira de leitura dos ícones registrados no macOS. Não abre aplicativos nem
/// acessa seus documentos. O resultado é um valor de apresentação, sem AppKit nas views.
@MainActor
enum ApplicationIconService {
    static func image(for url: URL?) -> Image? {
        guard let url else { return nil }
        return Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
    }
}
