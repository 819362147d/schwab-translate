import AVFoundation
import AVKit
import Combine
import CoreMedia
import Foundation
import UIKit

/// Owns the floating PiP window. Feeds rendered translation cards into an
/// AVSampleBufferDisplayLayer and presents it as Picture in Picture with
/// AVPictureInPictureController (custom content source, iOS 15+). No AVPlayer,
/// no HLS, no video encoding: the display layer holds the last card, so one
/// new frame per second is enough for a live translation window.
///
/// The app stays alive in the background via the audio background mode +
/// an active playback audio session, which also keeps the loopback HTTP
/// server reachable from the broadcast extension.
final class PiPManager: NSObject, ObservableObject {
    static let shared = PiPManager()

    @Published var pipActive = false
    @Published var serverRunning = false
    @Published var lastFrameText = "还没有收到翻译帧"
    @Published var lastCard: UIImage?

    private let server = PiPServer()
    private var displayLayer: AVSampleBufferDisplayLayer?
    private var pipController: AVPictureInPictureController?
    private var timebase: CMTimebase?
    private var playing = true
    private var lastFrameDate: Date?
    private var fallbackTimer: Timer?

    private override init() {
        super.init()
    }

    var isSupported: Bool {
        AVPictureInPictureController.isPictureInPictureSupported()
    }

    func start() {
        guard isSupported else {
            lastFrameText = "这台设备不支持画中画"
            return
        }
        // Audio session keeps the app alive in the background while PiP runs.
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            // Continue anyway; PiP may still start.
        }
        setupDisplayLayer()
        server.onFrame = { [weak self] payload in self?.handleFrame(payload) }
        server.start()
        serverRunning = true

        // Waiting card until the first real frame arrives.
        let waiting = OverlayPayload(
            timestamp: Date().timeIntervalSince1970,
            imageBase64: "",
            boxes: [OcrBox(x: 0, y: 0, w: 0, h: 0, original: "Waiting for screen broadcast…", translated: "等待录屏开始…")]
        )
        handleFrame(waiting)
        startFallbackTimer()

        guard let layer = displayLayer else { return }
        let source = AVPictureInPictureController.ContentSource(sampleBufferDisplayLayer: layer, playbackDelegate: self)
        let controller = AVPictureInPictureController(contentSource: source)
        controller.delegate = self
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        pipController = controller
        controller.startPictureInPicture()
    }

    func stop() {
        pipController?.stopPictureInPicture()
        pipController = nil
        displayLayer?.flushAndRemoveImage()
        displayLayer = nil
        timebase = nil
        server.stop()
        serverRunning = false
        fallbackTimer?.invalidate()
        fallbackTimer = nil
        pipActive = false
        do { try AVAudioSession.sharedInstance().setActive(false) } catch {}
    }

    private func setupDisplayLayer() {
        let layer = AVSampleBufferDisplayLayer()
        layer.bounds = CGRect(x: 0, y: 0, width: PiPCardRenderer.cardWidth, height: PiPCardRenderer.cardHeight)
        layer.videoGravity = .resizeAspect
        var timebase: CMTimebase?
        CMTimebaseCreateWithSourceClock(allocator: kCFAllocatorDefault, sourceClock: CMClockGetHostTimeClock(), timebaseOut: &timebase)
        if let timebase = timebase {
            CMTimebaseSetRate(timebase, rate: 1.0)
            layer.controlTimebase = timebase
            self.timebase = timebase
        }
        displayLayer = layer
    }

    private func handleFrame(_ payload: OverlayPayload) {
        let card = PiPCardRenderer.cardImage(for: payload)
        lastCard = card
        lastFrameDate = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        lastFrameText = "已收到翻译帧 · \(formatter.string(from: Date())) · \(payload.boxes.count) 句"
        guard let layer = displayLayer, layer.isReadyForMoreMediaData else { return }
        let pts = CMTimeMakeWithSeconds(CACurrentMediaTime(), preferredTimescale: 600)
        if let sample = PiPCardRenderer.sampleBuffer(from: card, presentationTime: pts) {
            layer.enqueue(sample)
        }
    }

    private func startFallbackTimer() {
        fallbackTimer?.invalidate()
        // If the loopback HTTP link is down, fall back to the pasteboard bridge.
        fallbackTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if let last = self.lastFrameDate, Date().timeIntervalSince(last) < 5 { return }
            guard let payload = OverlayBridge.fetchLatest() else { return }
            if payload.timestamp != self.lastFrameDate?.timeIntervalSince1970 {
                self.handleFrame(payload)
            }
        }
    }
}

extension PiPManager: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        pipActive = true
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        pipActive = false
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        pipActive = false
        lastFrameText = "画中画启动失败：\(error.localizedDescription)"
    }
}

extension PiPManager: AVPictureInPictureSampleBufferPlaybackDelegate {
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {
        self.playing = playing
    }

    func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        CMTimeRange(start: .zero, duration: .positiveInfinity)
    }

    func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
        !playing
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion: @escaping @Sendable () -> Void) {
        completion()
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime) async {
        // No skipping in a live translation feed.
    }
}
