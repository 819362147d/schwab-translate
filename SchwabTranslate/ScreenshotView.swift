import SwiftUI
import PhotosUI

/// Pick a screenshot from Photos, OCR it, translate it,
/// and overlay the translations at the original positions.
struct ScreenshotView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var payload: OverlayPayload?
    @State private var processing = false
    @State private var showOriginal = false
    @State private var notice = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Label("选择一张截图", systemImage: "photo.on.rectangle")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .onChange(of: selectedItem) { _, item in
                    guard let item = item else { return }
                    process(item: item)
                }
                if processing {
                    ProgressView("识别翻译中…")
                }
                if !notice.isEmpty {
                    Text(notice)
                        .foregroundColor(.secondary)
                        .font(.footnote)
                }
                if let payload = payload {
                    Toggle("显示原文（对照 OCR 结果）", isOn: $showOriginal)
                        .padding(.horizontal)
                    OverlayImageView(payload: payload, showOriginal: showOriginal)
                } else {
                    Spacer()
                    Text("先截一张嘉信 App 的图，再回到这里选图翻译。\n译文会半透明盖在原来文字的位置上。")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                    Spacer()
                }
            }
            .navigationTitle("截图翻译")
        }
    }

    private func process(item: PhotosPickerItem) {
        processing = true
        notice = ""
        payload = nil
        item.loadTransferable(type: Data.self) { result in
            switch result {
            case .success(let data):
                guard let data = data,
                      let uiImage = UIImage(data: data),
                      let cgImage = ScreenshotView.cgImage(of: uiImage) else {
                    DispatchQueue.main.async {
                        self.processing = false
                        self.notice = "读取图片失败"
                    }
                    return
                }
                TranslationEngine.shared.process(cgImage: cgImage) { payload in
                    DispatchQueue.main.async {
                        self.processing = false
                        if let payload = payload {
                            self.payload = payload
                        } else {
                            self.notice = "没识别到英文文字，或者翻译接口没连上"
                        }
                    }
                }
            case .failure:
                DispatchQueue.main.async {
                    self.processing = false
                    self.notice = "读取图片失败"
                }
            }
        }
    }

    private static func cgImage(of uiImage: UIImage) -> CGImage? {
        if let cgImage = uiImage.cgImage {
            return cgImage
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: uiImage.size, format: format)
        return renderer.image { _ in
            uiImage.draw(in: CGRect(origin: .zero, size: uiImage.size))
        }.cgImage
    }
}
