//
//  ChannelDetailView.swift
//  LiveTV
//
//  Created by CodingGuru on 9/20/24.
//

import SwiftUI

struct ChannelDetailView: View {
    @ObservedObject var serverManager = ServerManager.shared
    let streamURL: String  // Pass the stream URL from the channel list
    @State private var showOverlay = false
    var body: some View {
        VStack {
            // Check if the URL is valid before creating the player view
            
            if let url = URL(string: streamURL) {
                ZStack {
                    AVPlayerView(streamURL: url)

                    // Overlay the TrackSelectionView on top of the player view
//                    if showOverlay {
//                        TrackSelectionView(avController: AVPlayerController(url: url))
//                            .transition(.move(edge: .bottom))  // Overlay transition effect
//                    }
//
//                    // Toggle button to show or hide the overlay
//                    VStack {
//                        Spacer()
//                        HStack {
//                            Spacer()
//                            Button(action: {
//                                withAnimation {
//                                    showOverlay.toggle()
//                                }
//                            }) {
//                                Image(systemName: showOverlay ? "xmark.circle.fill" : "line.horizontal.3.decrease.circle.fill")
//                                    .font(.system(size: 40))
//                                    .padding()
//                                    .foregroundColor(.white)
//                            }
//                        }
//                    }
                }
                .edgesIgnoringSafeArea(.all)
            } else {
                Text("Invalid stream URL")
            }
            
        }
        .onAppear {
            if !serverManager.isServerRunning {
                serverManager.startWebServer()
                print("Local webserver is starting now")
            }
        }
        
    }
}

#Preview {
    ChannelDetailView(streamURL: "http://192.168.8.173:5004/auto/v5.1")
}
