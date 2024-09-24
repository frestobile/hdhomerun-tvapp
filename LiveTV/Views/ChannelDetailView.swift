//
//  ChannelDetailView.swift
//  LiveTV
//
//  Created by CodingGuru on 9/20/24.
//

import SwiftUI

struct ChannelDetailView: View {
    let streamURL: String  // Pass the stream URL from the channel list
    var body: some View {
        VStack {
            // Check if the URL is valid before creating the player view
            
            if let url = URL(string: streamURL) {
                VideoPlayerView(streamURL: url)
                    .edgesIgnoringSafeArea(.all)
            } else {
                Text("Invalid stream URL")
            }
        }
        .navigationTitle("Now Playing")
    }
}

#Preview {
    ChannelDetailView(streamURL: "http://192.168.8.173:5004/auto/v5.1")
}
