import Foundation
import XCTest
@testable import AirShortcut

@MainActor
final class AppCommandRouterTests: XCTestCase {
    func testTypedCommandIsConsumedOnce() throws {
        let router = AppCommandRouter(notificationCenter: NotificationCenter())
        router.send(.createRule)
        let envelope = try XCTUnwrap(router.pendingCommand)

        guard case .createRule = router.consume(envelope) else {
            return XCTFail("Expected the typed create command")
        }

        XCTAssertNil(router.pendingCommand)
        XCTAssertNil(router.consume(envelope))
    }

    func testLegacyNotificationBecomesTypedCommand() async throws {
        let notificationCenter = NotificationCenter()
        let router = AppCommandRouter(notificationCenter: notificationCenter)

        notificationCenter.post(
            name: .airShortcutSelectSection,
            object: AirShortcutSection.laboratory.rawValue
        )
        await Task.yield()

        let envelope = try XCTUnwrap(router.pendingCommand)
        guard case let .selectSection(section) = envelope.command else {
            return XCTFail("Expected a typed section command")
        }
        XCTAssertEqual(section.rawValue, AirShortcutSection.laboratory.rawValue)
    }
}
