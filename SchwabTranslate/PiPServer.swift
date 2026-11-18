import Foundation
import Network

/// Tiny HTTP server on 127.0.0.1:8765 so the broadcast extension can push
/// translated frames to the app. No App Groups in an unsigned build, and the
/// pasteboard is too chatty for a live PiP feed, so loopback HTTP is the
/// bridge. The extension POSTs OverlayPayload JSON to /frame; the app
/// renders it into a text card and feeds it to the PiP display layer.
final class PiPServer {
    var onFrame: ((OverlayPayload) -> Void)?

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.kn.schwabtranslate.pipserver", qos: .userInitiated)

    func start() {
        guard listener == nil else { return }
        do {
            let listener = try NWListener(using: .tcp, on: NWEndpoint.Port(integerLiteral: 8765))
            listener.newConnectionHandler = { [weak self] connection in
                self?.handle(connection)
            }
            listener.start(queue: queue)
            self.listener = listener
        } catch {
            // Port unavailable; the pasteboard fallback still works.
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private struct HTTPRequest {
        var method: String
        var path: String
        var body: Data
        var complete: Bool
    }

    private static func parseRequest(_ data: Data) -> HTTPRequest? {
        guard let headerEnd = data.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let headerData = data[data.startIndex..<headerEnd.lowerBound]
        guard let header = String(data: headerData, encoding: .utf8) else { return nil }
        let lines = header.components(separatedBy: "\r\n")
        guard let first = lines.first else { return nil }
        let parts = first.components(separatedBy: " ")
        guard parts.count >= 2 else { return nil }
        var contentLength = 0
        for line in lines.dropFirst() {
            let kv = line.components(separatedBy: ":")
            if kv.count >= 2,
               kv[0].trimmingCharacters(in: .whitespaces).lowercased() == "content-length" {
                contentLength = Int(kv[1].trimmingCharacters(in: .whitespaces)) ?? 0
            }
        }
        let bodyStart = headerEnd.upperBound
        let available = data.count - bodyStart
        guard available >= contentLength else {
            return HTTPRequest(method: parts[0], path: parts[1], body: Data(), complete: false)
        }
        let body = data[bodyStart..<bodyStart + contentLength]
        return HTTPRequest(method: parts[0], path: parts[1], body: Data(body), complete: true)
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveLoop(connection, buffer: Data())
    }

    private func receiveLoop(_ connection: NWConnection, buffer: Data) {
        var buffer = buffer
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1024 * 1024) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            if let data = data, !data.isEmpty {
                buffer.append(data)
            }
            if let request = PiPServer.parseRequest(buffer), request.complete {
                if request.method == "POST", request.path == "/frame",
                   let payload = try? JSONDecoder().decode(OverlayPayload.self, from: request.body) {
                    DispatchQueue.main.async { self.onFrame?(payload) }
                }
                let response = "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nOK"
                connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
                    connection.cancel()
                })
                return
            }
            if isComplete || error != nil {
                connection.cancel()
                return
            }
            self.receiveLoop(connection, buffer: buffer)
        }
    }
}
