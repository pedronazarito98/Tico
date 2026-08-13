import XCTest
@testable import Tico

final class TriggerMatcherTests: XCTestCase {
    private let matcher = TriggerMatcher()

    func testKeyboardMatchRequiresExactKeyCodeAndModifiers() {
        let trigger = TriggerDefinition.keyboard(keyCode: 12, modifiers: [.command, .shift])

        XCTAssertTrue(
            matcher.matches(
                trigger,
                event: .keyboard(keyCode: 12, modifiers: [.shift, .command])
            )
        )
        XCTAssertFalse(
            matcher.matches(
                trigger,
                event: .keyboard(keyCode: 12, modifiers: [.command])
            )
        )
        XCTAssertFalse(
            matcher.matches(
                trigger,
                event: .keyboard(keyCode: 13, modifiers: [.command, .shift])
            )
        )
    }

    func testMouseMatchRequiresButtonAndExactModifiers() {
        let trigger = TriggerDefinition.mouseButton(button: 3, modifiers: [.option])

        XCTAssertTrue(matcher.matches(trigger, event: .mouseButton(3, modifiers: [.option])))
        XCTAssertFalse(matcher.matches(trigger, event: .mouseButton(4, modifiers: [.option])))
        XCTAssertFalse(matcher.matches(trigger, event: .mouseButton(3)))
    }

    func testTrackpadMatchRequiresSameGestureAndEventKind() {
        let trigger = TriggerDefinition.trackpad(gesture: .swipeLeft)

        XCTAssertTrue(matcher.matches(trigger, event: .trackpad(.swipeLeft)))
        XCTAssertFalse(matcher.matches(trigger, event: .trackpad(.swipeRight)))
        XCTAssertFalse(matcher.matches(trigger, event: .keyboard(keyCode: 123)))
    }

    func testTrackpadMatchRequiresFingerCountAndHonorsRegion() {
        let regional = TriggerDefinition.trackpad(
            gesture: .tap,
            fingerCount: 4,
            region: .topRight
        )
        XCTAssertTrue(matcher.matches(
            regional,
            event: .trackpad(.tap, fingerCount: 4, region: .topRight)
        ))
        XCTAssertFalse(matcher.matches(
            regional,
            event: .trackpad(.tap, fingerCount: 3, region: .topRight)
        ))
        XCTAssertFalse(matcher.matches(
            regional,
            event: .trackpad(.tap, fingerCount: 4, region: .bottomRight)
        ))

        let anywhere = TriggerDefinition.trackpad(
            gesture: .tap,
            fingerCount: 4,
            region: .any
        )
        XCTAssertTrue(matcher.matches(
            anywhere,
            event: .trackpad(.tap, fingerCount: 4, region: .bottomLeft)
        ))
    }

    func testMatchingRulesExcludesDisabledRulesAndPreservesInputOrder() {
        let first = makeRule(name: "Primeira", isEnabled: true)
        let disabled = makeRule(name: "Desativada", isEnabled: false)
        let third = makeRule(name: "Terceira", isEnabled: true)
        let nonMatching = makeRule(
            name: "Outra tecla",
            isEnabled: true,
            trigger: .keyboard(keyCode: 1, modifiers: [.command])
        )

        let matches = matcher.matchingRules(
            in: [first, disabled, third, nonMatching],
            for: .keyboard(keyCode: 0, modifiers: [.command])
        )

        XCTAssertEqual(matches.map(\.id), [first.id, third.id])
    }

    func testMalformedDescriptorDoesNotMatchAnotherKind() {
        let event = InputEventDescriptor(
            kind: .mouseButton,
            keyCode: 12,
            modifiers: [.command],
            mouseButton: nil
        )

        XCTAssertFalse(
            matcher.matches(
                .keyboard(keyCode: 12, modifiers: [.command]),
                event: event
            )
        )
    }

    func testTrackpadSpecMatchesRangeVelocityEndRegionAndDevice() {
        let spec = TrackpadTriggerSpec(
            gesture: .swipeRight,
            fingerCount: 3...5,
            startRegion: .topLeft,
            endRegion: .topRight,
            minimumVelocity: 0.5,
            maximumVelocity: 2,
            pressureThreshold: 0.3,
            deviceScope: .device(id: "magic-trackpad")
        )
        let semanticEvent = GestureEvent(
            sessionID: UUID(),
            kind: .swipeRight,
            phase: .ended,
            fingerCount: 4,
            deviceID: "magic-trackpad",
            startRegion: .topLeft,
            endRegion: .topRight,
            velocity: 1.2,
            pressure: 0.5,
            confidence: 0.9,
            occurredAt: Date()
        )

        XCTAssertTrue(matcher.matches(.trackpad(spec: spec), event: .trackpad(semanticEvent)))

        var wrongDeviceSpec = spec
        wrongDeviceSpec.deviceScope = .device(id: "internal")
        XCTAssertFalse(
            matcher.matches(.trackpad(spec: wrongDeviceSpec), event: .trackpad(semanticEvent))
        )
    }

    private func makeRule(
        name: String,
        isEnabled: Bool,
        trigger: TriggerDefinition = .keyboard(keyCode: 0, modifiers: [.command])
    ) -> ShortcutRule {
        ShortcutRule(
            name: name,
            isEnabled: isEnabled,
            trigger: trigger,
            action: .notification(title: "Teste", body: "")
        )
    }
}
