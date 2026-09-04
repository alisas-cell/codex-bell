import Foundation

public struct DockGeometry: Sendable, Equatable {
    public static let defaultPanelWidth = 280.0
    public static let defaultPanelHeight = 700.0
    public static let sideHandleSize = BellSize(width: 24, height: 68)
    public static let urgentPeekDepth = 52.0

    public var visibleFrame: BellRect
    public var desiredPanelWidth: Double
    public var desiredPanelHeight: Double
    public var verticalFraction: Double

    public init(
        visibleFrame: BellRect,
        panelWidth: Double = DockGeometry.defaultPanelWidth,
        panelHeight: Double = DockGeometry.defaultPanelHeight,
        verticalFraction: Double = 0.5
    ) {
        self.visibleFrame = visibleFrame
        self.desiredPanelWidth = panelWidth
        self.desiredPanelHeight = panelHeight
        self.verticalFraction = Self.clamp(verticalFraction, lower: 0, upper: 1)
    }

    public var expandedSize: BellSize {
        let conventionalWidth = Self.clamp(desiredPanelWidth, lower: 276, upper: 286)
        let width = min(max(1, visibleFrame.width), conventionalWidth)
        let maximumHeight = max(1, visibleFrame.height * 0.78)
        let height = min(maximumHeight, max(1, desiredPanelHeight))
        return BellSize(width: width, height: height)
    }

    public func expandedFrame(for anchor: DockAnchor) -> BellRect {
        let size = expandedSize
        let availableY = max(0, visibleFrame.height - size.height)
        let sideY = visibleFrame.minY + availableY * verticalFraction
        switch anchor {
        case .left:
            return BellRect(x: visibleFrame.minX, y: sideY, width: size.width, height: size.height)
        case .right:
            return BellRect(x: visibleFrame.maxX - size.width, y: sideY, width: size.width, height: size.height)
        }
    }

    public func handleFrame(for anchor: DockAnchor) -> BellRect {
        let size = Self.sideHandleSize
        let y = visibleFrame.minY + max(0, visibleFrame.height - size.height) * verticalFraction
        let x = anchor == .left ? visibleFrame.minX : visibleFrame.maxX - size.width
        return BellRect(x: x, y: y, width: size.width, height: size.height)
    }

    public func urgentHandleFrame(for anchor: DockAnchor) -> BellRect {
        let handle = handleFrame(for: anchor)
        let width = min(Self.urgentPeekDepth, visibleFrame.width)
        let x = anchor == .left ? visibleFrame.minX : visibleFrame.maxX - width
        return BellRect(x: x, y: handle.minY, width: width, height: handle.height)
    }

    public func snapAnchor(for releasedFrame: BellRect) -> DockAnchor {
        snapAnchor(forReleaseX: releasedFrame.midX)
    }

    public func snapAnchor(forReleaseX x: Double) -> DockAnchor {
        x < visibleFrame.midX ? .left : .right
    }

    public func rehome(anchor: DockAnchor) -> BellRect {
        expandedFrame(for: anchor)
    }

    public func recoveredFrame(anchor: DockAnchor) -> BellRect {
        expandedFrame(for: anchor)
    }

    private static func clamp(_ value: Double, lower: Double, upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}
