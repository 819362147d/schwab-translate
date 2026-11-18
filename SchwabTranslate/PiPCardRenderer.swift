import CoreMedia
import CoreVideo
import Foundation
import UIKit

/// Renders the translated sentences as a text card (original + translation),
/// like TransPeek's floating window. The card shows TEXT ONLY, never the
/// screen image, so the PiP window can never capture itself recursively
/// while the broadcast is running.
enum PiPCardRenderer {
    static let cardWidth: CGFloat = 960
    static let cardHeight: CGFloat = 640

    static func cardImage(for payload: OverlayPayload) -> UIImage {
        let size = CGSize(width: cardWidth, height: cardHeight)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            UIColor(red: 0.07, green: 0.07, blue: 0.07, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            // Header.
            let header = "EN → 简"
            let headerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 26, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.6),
            ]
            (header as NSString).draw(at: CGPoint(x: 28, y: 22), withAttributes: headerAttrs)
            let count = "\(payload.boxes.count) 句"
            let countAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .regular),
                .foregroundColor: UIColor.systemYellow,
            ]
            let countSize = (count as NSString).size(withAttributes: countAttrs)
            (count as NSString).draw(at: CGPoint(x: size.width - 28 - countSize.width, y: 24), withAttributes: countAttrs)

            // Body: original (gray) + translated (white, bold), up to 6 pairs.
            var y: CGFloat = 72
            let maxWidth = size.width - 56
            for box in payload.boxes.prefix(6) {
                if y > size.height - 90 { break }
                let origAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 27, weight: .regular),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.65),
                ]
                let origRect = (box.original as NSString).boundingRect(
                    with: CGSize(width: maxWidth, height: 200),
                    options: [.usesLineFragmentOrigin],
                    attributes: origAttrs,
                    context: nil
                )
                (box.original as NSString).draw(
                    with: CGRect(x: 28, y: y, width: maxWidth, height: origRect.height),
                    options: [.usesLineFragmentOrigin],
                    attributes: origAttrs,
                    context: nil
                )
                y += origRect.height + 4
                let transAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 33, weight: .semibold),
                    .foregroundColor: UIColor.white,
                ]
                let transRect = (box.translated as NSString).boundingRect(
                    with: CGSize(width: maxWidth, height: 220),
                    options: [.usesLineFragmentOrigin],
                    attributes: transAttrs,
                    context: nil
                )
                (box.translated as NSString).draw(
                    with: CGRect(x: 28, y: y, width: maxWidth, height: transRect.height),
                    options: [.usesLineFragmentOrigin],
                    attributes: transAttrs,
                    context: nil
                )
                y += transRect.height + 18
            }
        }
    }

    static func pixelBuffer(from image: UIImage) -> CVPixelBuffer? {
        guard let cgImage = image.cgImage else { return nil }
        var buffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(image.size.width),
            Int(image.size.height),
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &buffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer = buffer else { return nil }
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: Int(image.size.width),
            height: Int(image.size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo.rawValue
        ) else { return nil }
        context.draw(cgImage, in: CGRect(origin: .zero, size: image.size))
        return pixelBuffer
    }

    static func sampleBuffer(from image: UIImage, presentationTime: CMTime) -> CMSampleBuffer? {
        guard let pixelBuffer = pixelBuffer(from: image) else { return nil }
        var formatDesc: CMFormatDescription?
        guard CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &formatDesc
        ) == noErr, let formatDesc = formatDesc else { return nil }
        var timing = CMSampleTimingInfo(
            duration: CMTime.invalid,
            presentationTimeStamp: presentationTime,
            decodeTimeStamp: CMTime.invalid
        )
        var sampleBuffer: CMSampleBuffer?
        let status = CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDesc,
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        )
        guard status == noErr else { return nil }
        return sampleBuffer
    }
}
