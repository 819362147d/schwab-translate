import SwiftUI

/// Shows the latest frame captured by the broadcast extension,
/// with translated text overlaid at the original positions.
struct LiveView: View {
    @State private var payload: OverlayPayload?
    @State private var lastSeen: TimeInterval = 0
    @State private var showOriginal = false
    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                if let payload = payload {
                    statusLine(for: payload)
                    OverlayImageView(payload: payload, showOriginal: showOriginal)
                    Toggle("显示原文（对照 OCR 结果）", isOn: $showOriginal)
                        .padding(.horizontal)
                } else {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "record.circle")
                            .font(.system(size: 44))
                            .foregroundColor(.secondary)
                        Text("还没有收到录屏翻译帧")
                            .font(.headline)
                        Text("先去嘉信 App 里开始录屏，译文会显示在这里。")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    Spacer()
                }
                HStack(spacing: 12) {
                    Link("打开嘉信官网", destination: URL(string: "https://client.schwab.com")!)
                        .font(.headline)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    Button("清除缓存帧") {
                        OverlayBridge.clear()
                        payload = nil
                        lastSeen = 0
                    }
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.secondary.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                howToCard
            }
            .navigationTitle("实时翻译")
            .onAppear(perform: refresh)
            .onReceive(timer) { _ in refresh() }
        }
    }

    private func refresh() {
        guard let latest = OverlayBridge.fetchLatest(),
              latest.timestamp != lastSeen else { return }
        lastSeen = latest.timestamp
        payload = latest
    }

    private func statusLine(for payload: OverlayPayload) -> some View {
        let date = Date(timeIntervalSince1970: payload.timestamp)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return HStack {
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
            Text("已收到翻译帧 · \(formatter.string(from: date)) · \(payload.boxes.count) 处文字")
                .font(.footnote)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal)
    }

    private var howToCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("怎么开始录屏翻译")
                .font(.headline)
            Text("1. 打开嘉信 App，到要翻译的页面。")
            Text("2. 从右上角下拉打开控制中心，长按“屏幕录制”。")
            Text("3. 选择 SchwabTranslate，点“开始直播”。")
            Text("4. 回到这里，最新一帧的译文会盖在原文位置上。")
            Text("5. 用完在控制中心点红色条停止录屏。")
        }
        .font(.footnote)
        .foregroundColor(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.secondary.opacity(0.12))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

/// Draws the captured frame with translated text at the original positions.
/// The image is fitted inside the available space and boxes are scaled to match.
struct OverlayImageView: View {
    let payload: OverlayPayload
    let showOriginal: Bool

    var body: some View {
        if let data = Data(base64Encoded: payload.imageBase64),
           let uiImage = UIImage(data: data) {
            GeometryReader { geo in
                let aspect = uiImage.size.width / uiImage.size.height
                let w = geo.size.width
                let h = geo.size.height
                let dw = min(w, h * aspect)
                let dh = dw / aspect
                let ox = (w - dw) / 2
                let oy = (h - dh) / 2
                ZStack(alignment: .topLeading) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .frame(width: dw, height: dh)
                    ForEach(Array(payload.boxes.enumerated()), id: \.offset) { _, box in
                        let fontSize = max(9, box.h * dh * 0.9)
                        Text(showOriginal ? box.original : box.translated)
                            .font(.system(size: fontSize, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(2)
                            .background(Color.black.opacity(0.55))
                            .cornerRadius(3)
                            .position(
                                x: ox + (box.x + box.w / 2) * dw,
                                y: oy + (box.y + box.h / 2) * dh
                            )
                    }
                }
                .frame(width: w, height: h)
            }
        } else {
            Text("图片解码失败")
                .foregroundColor(.secondary)
        }
    }
}
