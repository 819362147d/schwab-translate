import ReplayKit
import SwiftUI

struct PiPView: View {
    @StateObject private var pip = PiPManager.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    statusCard

                    if let card = pip.lastCard {
                        Image(uiImage: card)
                            .resizable()
                            .scaledToFit()
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
                            )
                    }

                    HStack(spacing: 12) {
                        Button(pip.pipActive ? "画中画已开启" : "开始画中画") {
                            pip.start()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(pip.pipActive)

                        Button("停止画中画") {
                            pip.stop()
                        }
                        .buttonStyle(.bordered)
                        .disabled(!pip.pipActive)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("开始录屏")
                            .font(.headline)
                        Text("点下面的录屏按钮，选 SchwabTranslate 开始直播；也可以在控制中心长按屏幕录制选它。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        BroadcastPickerButton()
                            .frame(height: 50)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)

                    howToCard
                }
                .padding()
            }
            .navigationTitle("画中画")
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("状态")
                    .font(.headline)
                Spacer()
                Text(pip.pipActive ? "悬浮中" : "未开启")
                    .font(.subheadline)
                    .foregroundStyle(pip.pipActive ? .green : .secondary)
            }
            Text(pip.lastFrameText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(pip.serverRunning ? "本地推流服务：运行中" : "本地推流服务：未运行")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var howToCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("用法")
                .font(.headline)
            Text("1. 点“开始画中画”，窗口会先浮出来，显示“等待录屏开始”。\n2. 点录屏按钮选 SchwabTranslate 开始直播。\n3. 去嘉信 App，画中画窗口浮在上面，拖到想看的位置，译文一句一句显示。\n4. 用完先停直播，再点“停止画中画”。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("窗口里只显示译文句子，不显示屏幕画面，所以录屏不会把窗口自己拍进去。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct BroadcastPickerButton: UIViewRepresentable {
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView()
        picker.preferredExtension = "com.kn.schwabtranslate.broadcast"
        picker.showsMicrophoneButton = false
        return picker
    }

    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}
