import ReplayKit
import Vision
import CoreMedia
import UIKit

/// Broadcast upload extension: captures the screen while the user is in
/// another app (e.g. Schwab), OCRs each frame, translates it, and hands
/// the overlay payload to the containing app via the pasteboard bridge.
final class SampleHandler: RPBroadcastSampleHandler {
    private var broadcasting = false
    private var lastProcessDate = Date.distantPast
    private var processing = false
    private var lastPayload: OverlayPayload?
    private var emptyStreak = 0
    private lazy var ciContext = CIContext(options: nil)
    private let engine = TranslationEngine.shared

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        broadcasting = true
    }

    override func broadcastPaused() {
        broadcasting = false
    }

    override func broadcastResumed() {
        broadcasting = true
    }

    override func broadcastFinished() {
        broadcasting = false
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video, broadcasting else { return }
        let now = Date()
        guard now.timeIntervalSince(lastProcessDate) >= 1.0, !processing else { return }
        lastProcessDate = now
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        // Downscale before rendering: the extension has a tight memory limit.
        let maxSide = max(ciImage.extent.width, ciImage.extent.height)
        let scale = min(1.0, 960.0 / maxSide)
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = ciContext.createCGImage(scaled, from: scaled.extent) else { return }
        processing = true
        engine.process(cgImage: cgImage) { [weak self] payload in
            guard let self = self else { return }
            if let payload = payload {
                self.lastPayload = payload
                self.emptyStreak = 0
                OverlayBridge.publish(payload: payload)
                self.postToApp(payload: payload)
            } else if let last = self.lastPayload, self.emptyStreak < 2 {
                // One or two bad frames in a row: keep the boxes alive
                // instead of letting them drop.
                self.emptyStreak += 1
                var keepAlive = last
                keepAlive.timestamp = Date().timeIntervalSince1970
                OverlayBridge.publish(payload: keepAlive)
                self.postToApp(payload: keepAlive)
            }
            self.processing = false
        }
    }

    /// Push the payload to the app's loopback HTTP server for the PiP
    /// window. Fire-and-forget: if the app isn't running its server yet,
    /// the pasteboard bridge still carries the frame.
    private func postToApp(payload: OverlayPayload) {
        guard let data = try? JSONEncoder().encode(payload),
              let url = URL(string: "http://127.0.0.1:8765/frame") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 2
        URLSession.shared.dataTask(with: request).resume()
    }
}
