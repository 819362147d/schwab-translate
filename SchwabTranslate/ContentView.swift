import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            LiveView()
                .tabItem { Label("实时翻译", systemImage: "record.circle") }
            PiPView()
                .tabItem { Label("画中画", systemImage: "pip") }
            ScreenshotView()
                .tabItem { Label("截图翻译", systemImage: "photo") }
            HelpView()
                .tabItem { Label("说明", systemImage: "info.circle") }
        }
    }
}
