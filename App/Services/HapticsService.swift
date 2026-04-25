import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Thin wrapper around `UIFeedbackGenerator`s. All calls are no-ops when haptics
/// are disabled in `AppSettings`, or when running on a non-iOS platform target.
public final class HapticsService {

    public init() {}

    public enum Style {
        case light, medium, heavy, soft, rigid, selection
    }

    public enum Notification {
        case success, warning, error
    }

    public func tap(_ style: Style, enabled: Bool) {
        guard enabled else { return }
        #if canImport(UIKit) && os(iOS)
        switch style {
        case .selection:
            let g = UISelectionFeedbackGenerator()
            g.prepare()
            g.selectionChanged()
        default:
            let g = UIImpactFeedbackGenerator(style: style.uiKitStyle)
            g.prepare()
            g.impactOccurred()
        }
        #endif
    }

    public func notify(_ notification: Notification, enabled: Bool) {
        guard enabled else { return }
        #if canImport(UIKit) && os(iOS)
        let g = UINotificationFeedbackGenerator()
        g.prepare()
        switch notification {
        case .success: g.notificationOccurred(.success)
        case .warning: g.notificationOccurred(.warning)
        case .error:   g.notificationOccurred(.error)
        }
        #endif
    }
}

#if canImport(UIKit) && os(iOS)
private extension HapticsService.Style {
    var uiKitStyle: UIImpactFeedbackGenerator.FeedbackStyle {
        switch self {
        case .light:     return .light
        case .medium:    return .medium
        case .heavy:     return .heavy
        case .soft:      return .soft
        case .rigid:     return .rigid
        case .selection: return .light
        }
    }
}
#endif
