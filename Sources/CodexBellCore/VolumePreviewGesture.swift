import Foundation

public struct VolumePreviewGesture: Sendable, Equatable {
    private var active = false

    public init() {}

    public mutating func begin() {
        guard !active else { return }
        active = true
    }

    public mutating func update() {}

    @discardableResult
    public mutating func end() -> Bool {
        guard active else { return false }
        active = false
        return true
    }
}
