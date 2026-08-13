import ApplicationServices
import Foundation

enum AccessibilityValueDecoder {
    static func element(_ value: CFTypeRef?) -> AXUIElement? {
        guard let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        return unsafeBitCast(value, to: AXUIElement.self)
    }

    static func point(_ value: CFTypeRef?) -> CGPoint? {
        guard let axValue = axValue(value, expectedType: .cgPoint) else {
            return nil
        }
        var point = CGPoint.zero
        guard AXValueGetValue(axValue, .cgPoint, &point) else { return nil }
        return point
    }

    static func size(_ value: CFTypeRef?) -> CGSize? {
        guard let axValue = axValue(value, expectedType: .cgSize) else {
            return nil
        }
        var size = CGSize.zero
        guard AXValueGetValue(axValue, .cgSize, &size) else { return nil }
        return size
    }

    private static func axValue(
        _ value: CFTypeRef?,
        expectedType: AXValueType
    ) -> AXValue? {
        guard let value,
              CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }
        let axValue = unsafeBitCast(value, to: AXValue.self)
        guard AXValueGetType(axValue) == expectedType else { return nil }
        return axValue
    }
}
