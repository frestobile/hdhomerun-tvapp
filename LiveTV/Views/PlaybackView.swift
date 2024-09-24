//
//  PlaybackView.swift
//  LiveTV
//
//  Created by CodingGuru on 9/7/24.
//

import SwiftUI

struct PlaybackView: View {
    var channelName: String?

    var body: some View {
        VStack {
            if let channelName = channelName {
                Text("Playing \(channelName)")
                    .font(.largeTitle)
                    .padding()
            } else {
                Text("Playback Settings")
                    .font(.largeTitle)
                    .padding()
            }
        }
        .navigationTitle(channelName ?? "Playback")
    }
}

#Preview {
    PlaybackView()
}
