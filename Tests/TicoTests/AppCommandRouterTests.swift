import Foundation
import XCTest
@testable import Tico

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

    func testTicoNotificationBecomesTypedCommand() async throws {
        let notificationCenter = NotificationCenter()
        let router = AppCommandRouter(notificationCenter: notificationCenter)

        notificationCenter.post(
            name: .ticoSelectSection,
            object: TicoSection.laboratory.rawValue
        )
        await Task.yield()

        let envelope = try XCTUnwrap(router.pendingCommand)
        guard case let .selectSection(section) = envelope.command else {
            return XCTFail("Expected a typed section command")
        }
        XCTAssertEqual(section.rawValue, TicoSection.laboratory.rawValue)
    }
}
