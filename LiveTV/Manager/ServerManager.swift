//
//  VideoPlayer.swift
//  LiveTV
//
//  Created by CodingGuru on 9/16/24.
//
import Combine
import Foundation
import ffmpegkit
import GCDWebServer

class ServerManager: ObservableObject {
    static let shared = ServerManager()  // Singleton instance

    @Published var isServerRunning = false

    private var webServer = GCDWebServer()

    private init() {}  // Prevent external instantiation

    // Start the web server
    func startWebServer() {
        webServer.addGETHandler(forBasePath: "/", directoryPath: getDocumentsDirectory().path, indexFilename: nil, cacheAge: 3600, allowRangeRequests: true)

        do {
            try webServer.start(options: [
                GCDWebServerOption_Port: 9090,
                GCDWebServerOption_BindToLocalhost: true
            ])   // it starts always with http://localhost:9090/
            
            if webServer.isRunning {
                self.isServerRunning = true
            }
        } catch {
            print("Error starting web server: \(error)")
            self.isServerRunning = false
        }
       
    }

    // Stop the web server
    func stopWebServer() {
        if webServer.isRunning {
            webServer.stop()
            self.isServerRunning = false
            print("Web server stopped")
        }
    }
    
    func getDocumentsDirectory() -> URL {
        return FileManager.default.temporaryDirectory
    }
}
