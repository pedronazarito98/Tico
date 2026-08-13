import Foundation

struct CustomGestureTemplate: Identifiable, Codable, Hashable, Sendable {
    static let minimumSampleCount = 3
    static let maximumSampleCount = 5
    static let defaultPointCount = 32

    var id: UUID
    var name: String
    var fingerCount: ClosedRange<Int>
    var samplePaths: [[TrackpadPoint]]
    var tolerance: Double
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        fingerCount: ClosedRange<Int>,
        samplePaths: [[TrackpadPoint]],
        tolerance: Double = 0.2,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.fingerCount = fingerCount
        self.samplePaths = samplePaths
        self.tolerance = min(max(tolerance, 0.05), 0.5)
        self.createdAt = createdAt
    }

    var representativePath: [TrackpadPoint] {
        CustomGesturePath.average(samplePaths)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case fingerCount
        case samplePaths
        case tolerance
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let bounds = try container.decode(
            CustomGestureRangeBounds.self,
            forKey: .fingerCount
        )
        guard bounds.lowerBound <= bounds.upperBound else {
            throw DecodingError.dataCorruptedError(
                forKey: .fingerCount,
                in: container,
                debugDescription: "A faixa de dedos está invertida."
            )
        }
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            name: try container.decode(String.self, forKey: .name),
            fingerCount: bounds.lowerBound...bounds.upperBound,
            samplePaths: try container.decode([[TrackpadPoint]].self, forKey: .samplePaths),
            tolerance: try container.decodeIfPresent(Double.self, forKey: .tolerance) ?? 0.2,
            createdAt: try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .distantPast
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(
            CustomGestureRangeBounds(
                lowerBound: fingerCount.lowerBound,
                upperBound: fingerCount.upperBound
            ),
            forKey: .fingerCount
        )
        try container.encode(samplePaths, forKey: .samplePaths)
        try container.encode(tolerance, forKey: .tolerance)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

private struct CustomGestureRangeBounds: Codable {
    let lowerBound: Int
    let upperBound: Int

    private enum CodingKeys: String, CodingKey {
        case lowerBound
        case upperBound
    }

    init(lowerBound: Int, upperBound: Int) {
        self.lowerBound = lowerBound
        self.upperBound = upperBound
    }

    init(from decoder: Decoder) throws {
        if var values = try? decoder.unkeyedContainer() {
            lowerBound = try values.decode(Int.self)
            upperBound = try values.decode(Int.self)
        } else {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            lowerBound = try container.decode(Int.self, forKey: .lowerBound)
            upperBound = try container.decode(Int.self, forKey: .upperBound)
        }
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.unkeyedContainer()
        try values.encode(lowerBound)
        try values.encode(upperBound)
    }
}

enum CustomGestureTrainingError: LocalizedError, Equatable {
    case insufficientSamples(required: Int)
    case invalidPath
    case inconsistentFingerCount

    var errorDescription: String? {
        switch self {
        case let .insufficientSamples(required):
            "Grave pelo menos \(required) amostras do mesmo gesto."
        case .invalidPath:
            "A trajetória ficou curta demais. Faça um movimento mais definido no trackpad."
        case .inconsistentFingerCount:
            "Use a mesma quantidade de dedos em todas as amostras."
        }
    }
}
