import Foundation
import UIKit

/// Extension <-> app bridge.
///
/// An unsigned sideloaded build has no App Groups entitlement, so the
/// general pasteboard carries the overlay payload and the app polls it.
/// The pasteboard item expires after one hour.
enum OverlayBridge {
    static let pasteboardType = "com.kn.schwabtranslate.overlay"

    static func publish(payload: OverlayPayload) {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        let pasteboard = UIPasteboard.general
        let item: [String: Any] = [pasteboardType: data]
        pasteboard.setItems([item], options: [
            .expirationDate: Date(timeIntervalSinceNow: 3600)
        ])
    }

    static func fetchLatest() -> OverlayPayload? {
        let pasteboard = UIPasteboard.general
        guard let data = pasteboard.data(forPasteboardType: pasteboardType) else { return nil }
        return try? JSONDecoder().decode(OverlayPayload.self, from: data)
    }

    static func clear() {
        UIPasteboard.general.setItems([], options: [:])
    }
}
