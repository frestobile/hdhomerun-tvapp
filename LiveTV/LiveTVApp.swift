import SwiftUI

@main
struct LiveTVApp: App {
    var body: some Scene {
        WindowGroup {
//            MainView()
            ChannelDetailView(streamURL: "http://192.168.8.173:5004/auto/v5.1")
        }
    }
}
