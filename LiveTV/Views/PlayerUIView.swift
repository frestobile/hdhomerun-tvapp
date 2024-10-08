//
//  PlayerUIView.swift
//  LiveTV
//
//  Created by CodingGuru on 10/7/24.
//


import SwiftUI

struct PlayerUIView: View {
    let streamURL: String  // Pass the stream URL from the channel list
    @State private var showOverlay = false
    @ObservedObject var serverManager = ServerManager.shared
    var body: some View {
        VStack {
            // Check if the URL is valid before creating the player view
            if serverManager.isLoading && serverManager.isServerRunning {
                ProgressView("Converting...")
            } else {
                PlayerView(streamURL: serverManager.streamURL!)
                    .onDisappear {
                        print("Playerview dismissed")
                    }
            }
            
        }
        .onAppear {
            serverManager.processStream(streamURL: streamURL)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: serverManager.waitForPlaylist)
        }
        .onDisappear {
            serverManager.isLoading = true
            serverManager.deleteHLSOutputFolder()
            serverManager.ffmpegSession?.cancel()
            serverManager.ffmpegSession = nil
        }
        
    }
}

#Preview {
    PlayerUIView(streamURL: "http://192.168.8.173:5004/auto/v5.1")
}
