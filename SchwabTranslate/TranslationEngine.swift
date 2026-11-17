import Foundation
import Vision
import CoreGraphics
import UIKit

/// One recognized text box. Coordinates are normalized 0...1, origin top-left.
struct OcrBox: Codable {
    var x: Double
    var y: Double
    var w: Double
    var h: Double
    var original: String
    var translated: String
}

struct OverlayPayload: Codable {
    var timestamp: Double
    var imageBase64: String
    var boxes: [OcrBox]
}

/// OCR (on-device Vision) + translation (Google free endpoint, needs network).
/// Shared by the app target and the broadcast extension target.
final class TranslationEngine {
    static let shared = TranslationEngine()
    private init() {}

    // MARK: - Public pipeline

    /// Recognize English text, translate each line to Chinese,
    /// and return a payload with a downscaled JPEG + boxes.
    func process(cgImage: CGImage, completion: @escaping (OverlayPayload?) -> Void) {
        guard let small = TranslationEngine.downscaled(cgImage, maxDimension: 960) else {
            completion(nil)
            return
        }
        recognizeText(in: small) { boxes in
            guard !boxes.isEmpty else {
                completion(nil)
                return
            }
            let originals = boxes.map { $0.original }
            self.translate(texts: originals) { translated in
                var out: [OcrBox] = []
                for (index, box) in boxes.enumerated() {
                    var b = box
                    if index < translated.count, !translated[index].isEmpty {
                        b.translated = translated[index]
                    } else {
                        b.translated = b.original
                    }
                    out.append(b)
                }
                guard let jpeg = TranslationEngine.jpegData(of: small, quality: 0.55) else {
                    completion(nil)
                    return
                }
                let payload = OverlayPayload(
                    timestamp: Date().timeIntervalSince1970,
                    imageBase64: jpeg.base64EncodedString(),
                    boxes: out
                )
                completion(payload)
            }
        }
    }

    // MARK: - OCR

    func recognizeText(in cgImage: CGImage, completion: @escaping ([OcrBox]) -> Void) {
        let request = VNRecognizeTextRequest { request, error in
            guard error == nil else {
                completion([])
                return
            }
            var boxes: [OcrBox] = []
            for observation in request.results as? [VNRecognizedTextObservation] ?? [] {
                guard let candidate = observation.topCandidates(1).first else { continue }
                let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                guard text.count >= 2 else { continue }
                let rect = observation.boundingBox
                // Vision origin is bottom-left; flip to top-left.
                let box = OcrBox(
                    x: Double(rect.origin.x),
                    y: Double(1.0 - rect.origin.y - rect.size.height),
                    w: Double(rect.size.width),
                    h: Double(rect.size.height),
                    original: text,
                    translated: ""
                )
                boxes.append(box)
            }
            completion(boxes)
        }
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en"]
        request.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                completion([])
            }
        }
    }

    // MARK: - Translation (Google free endpoint, no key)

    func translate(texts: [String], completion: @escaping ([String]) -> Void) {
        guard !texts.isEmpty else {
            completion([])
            return
        }
        let joined = texts.joined(separator: "\n")
        var components = URLComponents(string: "https://translate.googleapis.com/translate_a/single")!
        components.queryItems = [
            URLQueryItem(name: "client", value: "gtx"),
            URLQueryItem(name: "sl", value: "en"),
            URLQueryItem(name: "tl", value: "zh-CN"),
            URLQueryItem(name: "dt", value: "t"),
            URLQueryItem(name: "q", value: joined),
        ]
        guard let url = components.url else {
            completion(texts)
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [Any],
                  let segments = json.first as? [[Any]] else {
                completion(texts)
                return
            }
            var translated = ""
            for segment in segments {
                if let piece = segment.first as? String {
                    translated += piece
                }
            }
            let lines = translated.components(separatedBy: "\n")
            if lines.count == texts.count {
                completion(lines)
            } else {
                completion(texts)
            }
        }.resume()
    }

    // MARK: - Image helpers

    static func downscaled(_ image: CGImage, maxDimension: CGFloat) -> CGImage? {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let longest = max(width, height)
        guard longest > maxDimension else { return image }
        let scale = maxDimension / longest
        let newWidth = Int(width * scale)
        let newHeight = Int(height * scale)
        guard let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        return context.makeImage()
    }

    static func jpegData(of image: CGImage, quality: CGFloat) -> Data? {
        let uiImage = UIImage(cgImage: image)
        return uiImage.jpegData(compressionQuality: quality)
    }
}
