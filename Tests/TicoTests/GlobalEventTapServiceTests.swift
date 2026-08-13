import CoreGraphics
import XCTest
@testable import Tico

final class GlobalEventTapServiceTests: XCTestCase {
    func testStartRefusesMissingPermissionBeforeCreatingWorker() {
        let service = GlobalEventTapService(permissionCheck: { false })

        XCTAssertThrowsError(try service.start(onEvent: { _ in })) { error in
            XCTAssertEqual(error as? GlobalEventTapError, .inputMonitoringPermissionRequired)
        }
        XCTAssertFalse(service.isRunning)
    }

    func testNormalizesKeyboardEventAndModifiers() throws {
        let event = try XCTUnwrap(
            CGEvent(keyboardEventSource: nil, virtualKey: 12, keyDown: true)
        )
        event.flags = [.maskCommand, .maskShift]
        let timestamp = Date(timeIntervalSince1970: 42)

        let descriptor = GlobalEventTapService.normalize(
            type: .keyDown,
            event: event,
            timestamp: timestamp
        )

        XCTAssertEqual(descriptor, .keyboard(
            keyCode: 12,
            modifiers: [.command, .shift],
            timestamp: timestamp
        ))
    }

    func testNormalizesExtraMouseButton() throws {
        let event = try XCTUnwrap(
            CGEvent(
                mouseEventSource: nil,
                mouseType: .otherMouseDown,
                mouseCursorPosition: .zero,
                mouseButton: .center
            )
        )
        event.setIntegerValueField(.mouseEventButtonNumber, value: 4)

        let descriptor = GlobalEventTapService.normalize(type: .otherMouseDown, event: event)

        XCTAssertEqual(descriptor?.kind, .mouseButton)
        XCTAssertEqual(descriptor?.mouseButton, 4)
    }

    func testIgnoresUnsupportedEventType() throws {
        let event = try XCTUnwrap(
            CGEvent(keyboardEventSource: nil, virtualKey: 12, keyDown: false)
        )

        XCTAssertNil(GlobalEventTapService.normalize(type: .keyUp, event: event))
    }
}
