import Foundation

public struct BellPoint: Codable, Sendable, Equatable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct BellSize: Codable, Sendable, Equatable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public struct BellRect: Codable, Sendable, Equatable {
    public var origin: BellPoint
    public var size: BellSize

    public init(origin: BellPoint, size: BellSize) {
        self.origin = origin
        self.size = size
    }

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.init(origin: BellPoint(x: x, y: y), size: BellSize(width: width, height: height))
    }

    public var minX: Double { origin.x }
    public var minY: Double { origin.y }
    public var width: Double { size.width }
    public var height: Double { size.height }
    public var maxX: Double { origin.x + size.width }
    public var maxY: Double { origin.y + size.height }
    public var midX: Double { origin.x + size.width / 2 }
    public var midY: Double { origin.y + size.height / 2 }
}

public enum DockAnchor: String, Codable, CaseIterable, Sendable {
    case left
    case right

    public init(from decoder: Decoder) throws {
        let value = try? decoder.singleValueContainer().decode(String.self)
        self = value == Self.left.rawValue ? .left : .right
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var displayName: String {
        switch self {
        case .left: return "Left"
        case .right: return "Right"
        }
    }
}
