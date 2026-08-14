import Foundation

struct ShellNavigationSelection: Equatable {
    let selectedSection: TicoSection
    let changesDestination: Bool
    let searchText: String
    let dismissesSearch: Bool

    static func resolve(
        requestedSection: TicoSection?,
        currentSection: TicoSection
    ) -> Self? {
        guard let requestedSection else { return nil }

        return Self(
            selectedSection: requestedSection,
            changesDestination: requestedSection != currentSection,
            searchText: "",
            dismissesSearch: true
        )
    }
}
