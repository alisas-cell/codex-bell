import Foundation

public enum ApplicationActivationMode: Sendable, Equatable {
    case accessory
    case regular
}

public enum DockVisibilityPolicy {
    public static func activationMode(showInDock: Bool) -> ApplicationActivationMode {
        showInDock ? .regular : .accessory
    }
}

public enum CollapsePlacementPolicy {
    public static func destination(current: DockAnchor) -> DockAnchor {
        current
    }
}
