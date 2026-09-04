import Foundation

public struct VolumePreviewRequest: Sendable, Equatable {
    public let generation: UInt64
    public let volume: Double
}

public struct VolumePreviewDebouncer: Sendable, Equatable {
    public static let delay: TimeInterval = 0.5

    private var generation: UInt64 = 0
    private var pending: VolumePreviewRequest?

    public init() {}

    public var hasPendingPreview: Bool { pending != nil }

    @discardableResult
    public mutating func schedule(volume: Double) -> VolumePreviewRequest {
        generation &+= 1
        let request = VolumePreviewRequest(
            generation: generation,
            volume: min(max(volume, 0), 1)
        )
        pending = request
        return request
    }

    public mutating func consume(_ request: VolumePreviewRequest) -> VolumePreviewRequest? {
        guard pending?.generation == request.generation else { return nil }
        pending = nil
        return request
    }
}
