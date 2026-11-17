import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            LiveView()
                .tabItem { Label("实时翻译", systemImage: "record.circle") }
            ScreenshotView()
                .tabItem { Label("截图翻译", systemImage: "photo") }
            HelpView()
                .tabItem { Label("说明", systemImage: "info.circle") }
        }
    }
}
