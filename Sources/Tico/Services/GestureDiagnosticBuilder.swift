import Foundation

struct GestureCandidateQualification {
    let eligible: [GestureCandidate]
    let rejected: [GestureCandidate]
    let reasons: [String]
}

struct GestureDiagnosticBuilder {
    let configuration: GestureRecognizerConfiguration

    func qualify(
        _ candidates: [GestureCandidate],
        features: GestureFeatures
    ) -> GestureCandidateQualification {
        var eligible: [GestureCandidate] = []
        var rejected: [GestureCandidate] = []
        var reasons: [String] = []

        for candidate in candidates {
            let calibration = configuration.calibration(for: candidate.kind)
            var candidateReasons: [String] = []
            if candidate.confidence < calibration.confidenceThreshold {
                candidateReasons.append(
                    "confiança \(candidate.confidence.percentText) abaixo de "
                        + "\(calibration.confidenceThreshold.percentText)"
                )
            }
            if let minimumVelocity = calibration.minimumVelocity,
               features.motionVelocity < minimumVelocity {
                candidateReasons.append(
                    "velocidade \(features.motionVelocity.decimalText) abaixo do mínimo "
                        + "\(minimumVelocity.decimalText)"
                )
            }
            if let maximumVelocity = calibration.maximumVelocity,
               features.motionVelocity > maximumVelocity {
                candidateReasons.append(
                    "velocidade \(features.motionVelocity.decimalText) acima do máximo "
                        + "\(maximumVelocity.decimalText)"
                )
            }
            if candidateReasons.isEmpty {
                eligible.append(candidate)
            } else {
                rejected.append(candidate)
                reasons.append("\(candidate.kind.displayName): \(candidateReasons.joined(separator: "; ")).")
            }
        }
        return GestureCandidateQualification(
            eligible: eligible,
            rejected: rejected,
            reasons: reasons
        )
    }

    func diagnostic(
        features: GestureFeatures,
        candidates: [GestureCandidate],
        qualification: GestureCandidateQualification,
        decision: GestureArbitrationDecision
    ) -> GestureDiagnostic {
        if features.phase == .cancelled {
            return GestureDiagnostic(
                outcome: .cancelled,
                summary: "Sessão cancelada",
                reasons: ["Sleep, troca de provedor ou interrupção encerrou a sessão com segurança."]
            )
        }
        if features.phase != .ended, decision.accepted == nil {
            return .inProgress
        }
        if let accepted = decision.accepted {
            return GestureDiagnostic(
                outcome: .accepted,
                summary: "\(accepted.kind.displayName) aceito",
                reasons: [
                    accepted.evidence,
                    "Confiança \(accepted.confidence.percentText); velocidade "
                        + "\(features.motionVelocity.decimalText)."
                ]
            )
        }
        if features.maximumFingerCount < 2 {
            return GestureDiagnostic(
                outcome: .ignored,
                summary: "Movimento comum ignorado",
                reasons: ["A sessão usou apenas um dedo; regras avançadas exigem pelo menos dois."]
            )
        }
        if !qualification.reasons.isEmpty {
            return GestureDiagnostic(
                outcome: .rejected,
                summary: "Candidatos rejeitados pela calibração",
                reasons: qualification.reasons
            )
        }
        if candidates.isEmpty {
            return GestureDiagnostic(
                outcome: .rejected,
                summary: "Nenhum gesto atingiu os limiares",
                reasons: thresholdReasons(for: features)
            )
        }
        return GestureDiagnostic(
            outcome: .rejected,
            summary: "Gesto rejeitado na arbitragem",
            reasons: ["Outro candidato mais específico ou confiante venceu a sessão."]
        )
    }

    private func thresholdReasons(for features: GestureFeatures) -> [String] {
        var reasons: [String] = []
        let swipeDirection: TrackpadGesture
        if abs(features.displacement.x) > abs(features.displacement.y) {
            swipeDirection = features.displacement.x >= 0 ? .swipeRight : .swipeLeft
        } else {
            swipeDirection = features.displacement.y >= 0 ? .swipeUp : .swipeDown
        }
        let swipeMinimum = configuration.scaledMinimum(
            configuration.swipeMinimumDistance,
            for: swipeDirection
        )
        if features.distance < swipeMinimum {
            reasons.append(
                "Deslocamento \(features.distance.decimalText) menor que "
                    + "\(swipeMinimum.decimalText) para swipe."
            )
        }
        let pinchDirection: TrackpadGesture = features.relativeSpanChange >= 0 ? .pinchOut : .pinchIn
        let pinchMinimum = configuration.scaledMinimum(
            configuration.pinchMinimumChange,
            for: pinchDirection
        )
        if abs(features.relativeSpanChange) < pinchMinimum {
            reasons.append(
                "Variação de abertura \(abs(features.relativeSpanChange).percentText) menor que "
                    + "\(pinchMinimum.percentText) para pinça."
            )
        }
        let rotationDirection: TrackpadGesture = features.rotation >= 0
            ? .rotateCounterclockwise
            : .rotateClockwise
        let rotationMinimum = configuration.scaledMinimum(
            configuration.rotationMinimumRadians,
            for: rotationDirection
        )
        if abs(features.rotation) < rotationMinimum {
            reasons.append(
                "Rotação \(abs(features.rotation).decimalText) rad menor que "
                    + "\(rotationMinimum.decimalText) rad."
            )
        }
        let tapCalibration = configuration.calibration(for: .tap)
        if features.duration > configuration.tapMaximumDuration * tapCalibration.sensitivity {
            reasons.append("Duração longa demais para toque.")
        }
        return reasons.isEmpty ? ["A sessão terminou sem evidência suficiente."] : reasons
    }
}

private extension Double {
    var decimalText: String {
        formatted(.number.precision(.fractionLength(3)))
    }

    var percentText: String {
        formatted(.percent.precision(.fractionLength(0)))
    }
}
