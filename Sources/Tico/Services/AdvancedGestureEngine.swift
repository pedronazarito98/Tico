import Foundation

struct GestureProcessingOutput: Sendable {
    var pipelineTraceID: UUID? = nil
    var processingEpoch: CaptureGeneration? = nil
    let event: GestureEvent?
    let laboratorySnapshot: TrackpadLaboratorySnapshot?
    let completedFeatures: GestureFeatures?
    let activeTouchCount: Int?

    init(
        event: GestureEvent?,
        laboratorySnapshot: TrackpadLaboratorySnapshot?,
        completedFeatures: GestureFeatures? = nil,
        activeTouchCount: Int? = nil
    ) {
        self.event = event
        self.laboratorySnapshot = laboratorySnapshot
        self.completedFeatures = completedFeatures
        self.activeTouchCount = activeTouchCount
    }
}

struct AdvancedGestureEngine {
    private var sessionEngine = ContactSessionEngine()
    private let featureExtractor = GestureFeatureExtractor()
    private let tapHoldRecognizer: TapHoldGestureRecognizer
    private let directionalRecognizer: DirectionalGestureRecognizer
    private let pinchRotationRecognizer: PinchRotationRecognizer
    private let advancedFingerRecognizer: AdvancedFingerGestureRecognizer
    private let diagnosticBuilder: GestureDiagnosticBuilder
    private let arbiter: GestureArbiter
    private var consumedSessionID: UUID?
    private var activeEvent: GestureEvent?
    private var lastAdvancedTransitionCount = 0

    init(
        configuration: GestureRecognizerConfiguration = GestureRecognizerConfiguration(),
        arbiter: GestureArbiter = GestureArbiter(minimumConfidence: 0)
    ) {
        tapHoldRecognizer = TapHoldGestureRecognizer(configuration: configuration)
        directionalRecognizer = DirectionalGestureRecognizer(configuration: configuration)
        pinchRotationRecognizer = PinchRotationRecognizer(configuration: configuration)
        advancedFingerRecognizer = AdvancedFingerGestureRecognizer(configuration: configuration)
        diagnosticBuilder = GestureDiagnosticBuilder(configuration: configuration)
        self.arbiter = arbiter
    }

    /// O reconhecimento usa todos os quadros. A apresentação detalhada pode ser
    /// omitida nos quadros intermediários sem consumidor; eventos e finais ainda
    /// carregam o diagnóstico necessário ao relatório de validação.
    mutating func process(
        _ frame: RawTrackpadFrame,
        includeLaboratorySnapshot: Bool = true
    ) -> GestureProcessingOutput {
        guard let session = sessionEngine.process(frame),
              let features = featureExtractor.extract(from: session) else {
            return GestureProcessingOutput(event: nil, laboratorySnapshot: nil)
        }

        let candidates = tapHoldRecognizer.candidates(for: features)
            + directionalRecognizer.candidates(for: features)
            + pinchRotationRecognizer.candidates(for: features)
            + advancedFingerRecognizer.candidates(for: features)
        let qualification = diagnosticBuilder.qualify(
            candidates,
            features: features,
            includeReasons: includeLaboratorySnapshot || session.phase == .ended
        )
        let activeTouchCount = session.phase == .ended || session.phase == .cancelled
            ? 0
            : features.contacts.filter { $0.transition == .down || $0.transition == .move }.count
        if let activeEvent,
           activeEvent.sessionID == session.id,
           activeEvent.kind.supportsContinuousPhases,
           session.phase == .changed || session.phase == .ended {
            let phase: GesturePhase = session.phase == .ended ? .ended : .changed
            let event = GestureEvent(
                sessionID: session.id,
                kind: activeEvent.kind,
                phase: phase,
                fingerCount: features.maximumFingerCount,
                deviceID: features.deviceID,
                startRegion: activeEvent.startRegion,
                endRegion: features.currentRegion,
                startPosition: activeEvent.startPosition,
                endPosition: features.centroid,
                path: features.centroidPath,
                progress: continuousProgress(kind: activeEvent.kind, features: features),
                velocity: features.motionVelocity,
                pressure: features.pressure,
                confidence: activeEvent.confidence,
                advanced: activeEvent.advanced,
                occurredAt: features.occurredAt
            )
            let decision = GestureArbitrationDecision(
                accepted: nil,
                rejected: qualification.eligible
            )
            let snapshot: TrackpadLaboratorySnapshot?
            if includeLaboratorySnapshot || session.phase == .ended {
                snapshot = TrackpadLaboratorySnapshot(
                    sessionID: session.id,
                    phase: session.phase,
                    contacts: features.contacts,
                    features: features,
                    acceptedCandidate: nil,
                    rejectedCandidates: qualification.eligible + qualification.rejected,
                    diagnostic: diagnosticBuilder.diagnostic(
                        features: features,
                        candidates: candidates,
                        qualification: qualification,
                        decision: decision
                    )
                )
            } else {
                snapshot = nil
            }
            if session.phase == .ended {
                consumedSessionID = nil
                self.activeEvent = nil
                lastAdvancedTransitionCount = 0
            }
            return GestureProcessingOutput(
                event: event,
                laboratorySnapshot: snapshot,
                completedFeatures: session.phase == .ended ? features : nil,
                activeTouchCount: activeTouchCount
            )
        }
        let decision: GestureArbitrationDecision
        let hasFreshAdvancedCandidate = candidates.contains {
            $0.recognizer == .advancedFinger
                && features.transitions.count > lastAdvancedTransitionCount
        }
        if consumedSessionID == session.id && !hasFreshAdvancedCandidate {
            decision = GestureArbitrationDecision(accepted: nil, rejected: qualification.eligible)
        } else {
            decision = arbiter.decide(between: qualification.eligible)
        }

        var event: GestureEvent?
        if let accepted = decision.accepted {
            let value = GestureEvent(
                sessionID: session.id,
                kind: accepted.kind,
                phase: accepted.phase,
                fingerCount: features.maximumFingerCount,
                deviceID: features.deviceID,
                startRegion: features.startRegion,
                endRegion: features.currentRegion,
                startPosition: features.startCentroid,
                endPosition: features.centroid,
                path: features.centroidPath,
                progress: accepted.phase == .began
                    ? continuousProgress(kind: accepted.kind, features: features)
                    : nil,
                velocity: features.motionVelocity,
                pressure: features.pressure,
                confidence: accepted.confidence,
                advanced: accepted.advanced,
                occurredAt: features.occurredAt
            )
            if accepted.recognizer == .advancedFinger {
                lastAdvancedTransitionCount = features.transitions.count
            } else {
                consumedSessionID = session.id
            }
            activeEvent = value.phase == .began ? value : nil
            event = value
        }

        let laboratorySnapshot: TrackpadLaboratorySnapshot?
        if includeLaboratorySnapshot || event != nil || session.phase == .ended {
            laboratorySnapshot = TrackpadLaboratorySnapshot(
                sessionID: session.id,
                phase: session.phase,
                contacts: features.contacts,
                features: features,
                acceptedCandidate: decision.accepted,
                rejectedCandidates: decision.rejected + qualification.rejected,
                diagnostic: diagnosticBuilder.diagnostic(
                    features: features,
                    candidates: candidates,
                    qualification: qualification,
                    decision: decision
                )
            )
        } else {
            laboratorySnapshot = nil
        }
        if session.phase == .ended {
            consumedSessionID = nil
            activeEvent = nil
            lastAdvancedTransitionCount = 0
        }
        return GestureProcessingOutput(
            event: event,
            laboratorySnapshot: laboratorySnapshot,
            completedFeatures: session.phase == .ended ? features : nil,
            activeTouchCount: activeTouchCount
        )
    }

    mutating func cancel(at date: Date = Date()) -> GestureProcessingOutput {
        guard let session = sessionEngine.cancel(at: date),
              let features = featureExtractor.extract(from: session) else {
            consumedSessionID = nil
            activeEvent = nil
            return GestureProcessingOutput(event: nil, laboratorySnapshot: nil)
        }

        let cancelledEvent = activeEvent.map {
            GestureEvent(
                sessionID: session.id,
                kind: $0.kind,
                phase: .cancelled,
                fingerCount: $0.fingerCount,
                deviceID: $0.deviceID,
                startRegion: $0.startRegion,
                endRegion: features.currentRegion,
                startPosition: $0.startPosition,
                endPosition: features.centroid,
                path: features.centroidPath,
                velocity: features.motionVelocity,
                pressure: features.pressure,
                confidence: $0.confidence,
                occurredAt: date
            )
        }
        consumedSessionID = nil
        activeEvent = nil
        lastAdvancedTransitionCount = 0
        return GestureProcessingOutput(
            event: cancelledEvent,
            laboratorySnapshot: TrackpadLaboratorySnapshot(
                sessionID: session.id,
                phase: .cancelled,
                contacts: features.contacts,
                features: features,
                acceptedCandidate: nil,
                rejectedCandidates: [],
                diagnostic: GestureDiagnostic(
                    outcome: .cancelled,
                    summary: "Sessão cancelada",
                    reasons: ["A captura foi interrompida com segurança."]
                )
            )
        )
    }

    mutating func reset() {
        sessionEngine.reset()
        consumedSessionID = nil
        activeEvent = nil
        lastAdvancedTransitionCount = 0
    }

    private func continuousProgress(
        kind: TrackpadGesture,
        features: GestureFeatures
    ) -> Double {
        let raw: Double
        switch kind {
        case .swipeLeft, .swipeRight, .swipeUp, .swipeDown:
            raw = features.distance / 0.45
        case .pinchIn, .pinchOut:
            raw = abs(features.relativeSpanChange) / 0.6
        case .rotateClockwise, .rotateCounterclockwise:
            raw = abs(features.rotation) / .pi
        case .tap, .hold, .tipTapLeft, .tipTapRight, .addFinger,
             .removeFinger, .fingerChord:
            raw = 0
        }
        return min(max(raw, 0), 1)
    }
}

private extension TrackpadGesture {
    var supportsContinuousPhases: Bool {
        switch self {
        case .swipeLeft, .swipeRight, .swipeUp, .swipeDown,
             .pinchIn, .pinchOut, .rotateClockwise, .rotateCounterclockwise:
            true
        case .tap, .hold, .tipTapLeft, .tipTapRight, .addFinger,
             .removeFinger, .fingerChord:
            false
        }
    }
}
