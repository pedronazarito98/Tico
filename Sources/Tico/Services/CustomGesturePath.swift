import Foundation

enum CustomGesturePath {
    struct Recognition: Equatable {
        var templateID: UUID
        var distance: Double
        var confidence: Double
        var marginToSecondBest: Double?
    }

    static func train(
        name: String,
        from events: [InputEventDescriptor],
        pointCount: Int = CustomGestureTemplate.defaultPointCount
    ) throws -> CustomGestureTemplate {
        guard events.count >= CustomGestureTemplate.minimumSampleCount else {
            throw CustomGestureTrainingError.insufficientSamples(
                required: CustomGestureTemplate.minimumSampleCount
            )
        }
        let counts = events.compactMap(\.fingerCount)
        guard counts.count == events.count, Set(counts).count == 1, let count = counts.first else {
            throw CustomGestureTrainingError.inconsistentFingerCount
        }
        let paths = try events.map { event in
            guard let path = normalized(event.trackpadPath, pointCount: pointCount) else {
                throw CustomGestureTrainingError.invalidPath
            }
            return path
        }
        return CustomGestureTemplate(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Gesto personalizado"
                : name,
            fingerCount: count...count,
            samplePaths: paths
        )
    }

    static func matches(
        _ path: [TrackpadPoint],
        template: CustomGestureTemplate
    ) -> Bool {
        guard let candidate = normalized(path, pointCount: CustomGestureTemplate.defaultPointCount),
              !template.representativePath.isEmpty else {
            return false
        }
        return distance(candidate, template.representativePath) <= template.tolerance
    }

    static func recognize(
        _ path: [TrackpadPoint],
        fingerCount: Int,
        templates: [CustomGestureTemplate],
        minimumMargin: Double = 0.03
    ) -> Recognition? {
        guard let candidate = normalized(
            path,
            pointCount: CustomGestureTemplate.defaultPointCount
        ) else {
            return nil
        }
        let ranked = templates
            .filter { $0.fingerCount.contains(fingerCount) && !$0.representativePath.isEmpty }
            .map { template in
                (
                    template: template,
                    distance: distance(candidate, template.representativePath)
                )
            }
            .sorted { $0.distance < $1.distance }
        guard let best = ranked.first, best.distance <= best.template.tolerance else {
            return nil
        }
        let secondDistance = ranked.dropFirst().first?.distance
        let margin = secondDistance.map { $0 - best.distance }
        guard margin == nil || margin! >= minimumMargin else {
            return nil
        }
        let confidence = 1 - min(best.distance / max(best.template.tolerance, 0.001), 1)
        return Recognition(
            templateID: best.template.id,
            distance: best.distance,
            confidence: confidence,
            marginToSecondBest: margin
        )
    }

    static func normalized(
        _ path: [TrackpadPoint],
        pointCount: Int
    ) -> [TrackpadPoint]? {
        let simplified = path.reduce(into: [TrackpadPoint]()) { result, point in
            if result.last?.distance(to: point) ?? .greatestFiniteMagnitude >= 0.001 {
                result.append(point)
            }
        }
        guard simplified.count >= 2 else { return nil }
        let totalLength = zip(simplified, simplified.dropFirst())
            .reduce(0) { $0 + $1.0.distance(to: $1.1) }
        guard totalLength >= 0.035 else { return nil }

        let resampled = resample(simplified, pointCount: max(2, pointCount))
        guard let first = resampled.first else { return nil }
        let translated = resampled.map {
            TrackpadPoint(x: $0.x - first.x, y: $0.y - first.y)
        }
        let minX = translated.map(\.x).min() ?? 0
        let maxX = translated.map(\.x).max() ?? 0
        let minY = translated.map(\.y).min() ?? 0
        let maxY = translated.map(\.y).max() ?? 0
        let scale = max(maxX - minX, maxY - minY)
        guard scale >= 0.001 else { return nil }
        return translated.map {
            TrackpadPoint(x: $0.x / scale, y: $0.y / scale)
        }
    }

    static func average(_ paths: [[TrackpadPoint]]) -> [TrackpadPoint] {
        guard let count = paths.first?.count,
              count > 0,
              paths.allSatisfy({ $0.count == count }) else {
            return []
        }
        return (0..<count).map { index in
            let total = paths.reduce((x: 0.0, y: 0.0)) {
                ($0.x + $1[index].x, $0.y + $1[index].y)
            }
            return TrackpadPoint(
                x: total.x / Double(paths.count),
                y: total.y / Double(paths.count)
            )
        }
    }

    static func distance(_ lhs: [TrackpadPoint], _ rhs: [TrackpadPoint]) -> Double {
        guard lhs.count == rhs.count, !lhs.isEmpty else {
            return .greatestFiniteMagnitude
        }
        return zip(lhs, rhs).reduce(0) {
            $0 + $1.0.distance(to: $1.1)
        } / Double(lhs.count)
    }

    private static func resample(
        _ path: [TrackpadPoint],
        pointCount: Int
    ) -> [TrackpadPoint] {
        let lengths = zip(path, path.dropFirst()).map { $0.distance(to: $1) }
        let total = lengths.reduce(0, +)
        guard total > 0 else { return Array(repeating: path[0], count: pointCount) }

        var result = [path[0]]
        var segmentIndex = 0
        var traversed = 0.0
        for index in 1..<pointCount {
            let target = total * Double(index) / Double(pointCount - 1)
            while segmentIndex < lengths.count - 1,
                  traversed + lengths[segmentIndex] < target {
                traversed += lengths[segmentIndex]
                segmentIndex += 1
            }
            let segmentLength = max(lengths[segmentIndex], .leastNonzeroMagnitude)
            let progress = min(max((target - traversed) / segmentLength, 0), 1)
            let start = path[segmentIndex]
            let end = path[segmentIndex + 1]
            result.append(TrackpadPoint(
                x: start.x + (end.x - start.x) * progress,
                y: start.y + (end.y - start.y) * progress
            ))
        }
        return result
    }
}
