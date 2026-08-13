import TicoMultitouchBridge
import Foundation

/// The C bridge may invoke `receive` off the main actor. The owning
/// `TrackpadGestureService` serializes provider lifecycle calls and keeps the
/// provider alive until `stop` has released the retained callback context.
/// No caller may invoke `start` and `stop` concurrently with each other.
final class MultitouchFrameProvider: TrackpadFrameProvider, @unchecked Sendable {
    let capabilities = TrackpadProviderCapabilities.privateMultitouch
    private(set) var isRunning = false

    private var rawHandle: TicoMultitouchHandle?
    private var frameHandler: (@Sendable (RawTrackpadFrame) -> Void)?
    private var callbackContextPointer: UnsafeMutableRawPointer?

    deinit {
        stop()
    }

    func start(onFrame: @escaping @Sendable (RawTrackpadFrame) -> Void) throws {
        guard !isRunning else { throw TrackpadFrameProviderError.alreadyRunning }
        guard TicoMultitouchFrameworkIsAvailable() else {
            throw TrackpadFrameProviderError.unavailable(
                "MultitouchSupport não está disponível nesta versão do macOS."
            )
        }

        frameHandler = onFrame
        let callbackContext = MultitouchCallbackContext(provider: self)
        let context = Unmanaged.passRetained(callbackContext).toOpaque()
        guard let handle = TicoMultitouchCreate(multitouchFrameProviderCallback, context) else {
            Unmanaged<MultitouchCallbackContext>.fromOpaque(context).release()
            frameHandler = nil
            throw TrackpadFrameProviderError.unavailable(Self.bridgeError())
        }
        let status = TicoMultitouchStart(handle)
        guard status == 0 else {
            TicoMultitouchDestroy(handle)
            Unmanaged<MultitouchCallbackContext>.fromOpaque(context).release()
            frameHandler = nil
            throw TrackpadFrameProviderError.unavailable(Self.bridgeError())
        }
        rawHandle = handle
        callbackContextPointer = context
        isRunning = true
    }

    func stop() {
        if let rawHandle {
            TicoMultitouchStop(rawHandle)
            TicoMultitouchDestroy(rawHandle)
        }
        if let callbackContextPointer {
            Unmanaged<MultitouchCallbackContext>
                .fromOpaque(callbackContextPointer)
                .release()
        }
        rawHandle = nil
        callbackContextPointer = nil
        frameHandler = nil
        isRunning = false
    }

    fileprivate func receive(
        touches: UnsafePointer<TicoRawTouch>?,
        touchCount: Int32,
        timestamp: Double,
        frame: Int32
    ) {
        guard touchCount >= 0, let frameHandler else { return }
        let values: [RawTrackpadTouch]
        if let touches, touchCount > 0 {
            values = UnsafeBufferPointer(start: touches, count: Int(touchCount)).map { touch in
                RawTrackpadTouch(
                    identifier: touch.identifier,
                    state: touch.state,
                    position: TrackpadPoint(
                        x: Double(touch.normalizedX),
                        y: Double(touch.normalizedY)
                    ),
                    velocity: TrackpadPoint(
                        x: Double(touch.velocityX),
                        y: Double(touch.velocityY)
                    ),
                    pressure: Double(touch.pressure)
                )
            }
        } else {
            values = []
        }
        frameHandler(
            RawTrackpadFrame(
                touches: values,
                deviceTimestamp: timestamp,
                frameNumber: frame,
                receivedAt: Date()
            )
        )
    }

    private static func bridgeError() -> String {
        guard let pointer = TicoMultitouchLastError() else {
            return "Falha desconhecida ao iniciar o trackpad."
        }
        let value = String(cString: pointer)
        return value.isEmpty ? "Falha desconhecida ao iniciar o trackpad." : value
    }
}

private final class MultitouchCallbackContext {
    weak var provider: MultitouchFrameProvider?

    init(provider: MultitouchFrameProvider) {
        self.provider = provider
    }
}

private func multitouchFrameProviderCallback(
    _ touches: UnsafePointer<TicoRawTouch>?,
    _ touchCount: Int32,
    _ timestamp: Double,
    _ frame: Int32,
    _ context: UnsafeMutableRawPointer?
) {
    guard let context else { return }
    guard let provider = Unmanaged<MultitouchCallbackContext>
        .fromOpaque(context)
        .takeUnretainedValue()
        .provider else {
        return
    }
    provider.receive(
        touches: touches,
        touchCount: touchCount,
        timestamp: timestamp,
        frame: frame
    )
}
