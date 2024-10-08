import SwiftUI

@main
struct LiveTVApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            MainView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Start the web server when the app launches
        ServerManager.shared.startWebServer()
        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Stop the web server when the app is terminated
        ServerManager.shared.stopWebServer()
    }
}
