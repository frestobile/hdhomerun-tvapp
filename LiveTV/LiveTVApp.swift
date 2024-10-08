import SwiftUI

@main
struct LiveTVApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            MainView()
//            ChannelDetailView(streamURL: "http://192.168.8.173:5004/auto/v5.1")
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Start the web server when the app launches
//        let outputDirectory = NSTemporaryDirectory()
        ServerManager.shared.startWebServer()
        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Stop the web server when the app is terminated
        ServerManager.shared.stopWebServer()
    }
}
