import SwiftUI

struct HelpView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("这个 App 是干什么的")
                        .font(.headline)
                    Text("给嘉信（Charles Schwab）App 用的实时翻译：录屏时识别画面里的英文，翻成中文，半透明盖在原来文字的位置上。不用一个个复制去查。")
                    Text("两种用法")
                        .font(.headline)
                    Text("实时翻译：在嘉信 App 里开录屏直播（控制中心 → 长按屏幕录制 → 选 SchwabTranslate），切回这里看译文。扩展每 1.5 秒抓一帧识别翻译。\n\n截图翻译：截一张图，在“截图翻译”里选图，识别完直接看。")
                    Text("实话实说：做不到的事")
                        .font(.headline)
                    Text("iOS 不允许第三方 App 在别的 App 界面上悬浮显示，所以译文不能直接浮在嘉信 App 上面，只能切回本 App 查看。这是系统限制，不是这个 App 的 bug。\n\n翻译走 Google 免费接口，需要联网；断网时只能识别原文，翻不出来。\n\n录屏扩展在系统里内存有限，抓帧频率不高，画面切得太快会漏帧，等 1–2 秒会刷新。")
                    Text("安装")
                        .font(.headline)
                    Text("这是未签名 IPA，用 AltStore / Sideloadly / SideStore 拿自己的 Apple ID 自签安装。免费账号证书 7 天有效，到期重签。装好后第一次用录屏翻译，要在控制中心长按屏幕录制，列表里选 SchwabTranslate。")
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("说明")
        }
    }
}
