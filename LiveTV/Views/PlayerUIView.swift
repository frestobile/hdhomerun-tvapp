//
//  PlayerUIView.swift
//  LiveTV
//
//  Created by CodingGuru on 10/7/24.
//

import SwiftUI
import AVKit

struct PlayerUIView: View {
    let streamURL: String
    @ObservedObject var serverManager = ServerManager.shared
    var body: some View {
        VStack {
           if let streamURL = serverManager.streamURL, serverManager.isServerRunning {
               VideoPlayer(player: AVPlayer(url: streamURL))
                   .onAppear {
                       AVPlayer(url: streamURL).play()
                   }
           } else {
               Text("Converting video...")
           }
       }
        .onAppear {
            serverManager.processStream(streamURL: URL(string: streamURL)!)
            serverManager.waitForPlaylist()
        }
       .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    PlayerUIView(streamURL: "http://192.168.8.173:5004/auto/v5.1")
}
