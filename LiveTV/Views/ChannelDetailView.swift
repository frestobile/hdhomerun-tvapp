//
//  ChannelDetailView.swift
//  LiveTV
//
//  Created by CodingGuru on 9/20/24.
//

import SwiftUI
import AVKit

struct ChannelDetailView: View {
    @StateObject private var playerWrapper = VLCPlayerWrapper()
    @State private var isPlaying = false
    @State private var showControls = true
    let streamURL: String  // Pass the stream URL from the channel list
    var body: some View {
        ZStack {
            VideoPlayerView(playerWrapper: playerWrapper)
                .onAppear {
                    playerWrapper.playStream(url: URL(string: streamURL)!)
                }
                .onDisappear {
                    playerWrapper.stop()
                }

            if playerWrapper.isBuffering { // Show spinner when buffering
                ProgressView()
                    .scaleEffect(2.0)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .background(Color.black.opacity(0.5))
                    .edgesIgnoringSafeArea(.all)
            }

            if showControls {
                VStack {
                    Spacer()

                    HStack {
                        Button(action: {
                            playerWrapper.rewind()
                        }) {
                            Image(systemName: "gobackward.10")
                                .font(.largeTitle)
                                .padding()
                        }

                        Button(action: {
                            if playerWrapper.isPlaying {
                                playerWrapper.pause()
                            } else {
                                playerWrapper.playStream(url: URL(string: streamURL)!)
                            }
                        }) {
                            Image(systemName: playerWrapper.isPlaying ? "pause.fill" : "play.fill")
                                .font(.largeTitle)
                                .padding()
                        }

                        Button(action: {
                            playerWrapper.forward()
                        }) {
                            Image(systemName: "goforward.10")
                                .font(.largeTitle)
                                .padding()
                        }

                        Button(action: {
                            playerWrapper.startPiP() // Start Picture-in-Picture
                        }) {
                            Image(systemName: "pip.enter")
                                .font(.largeTitle)
                                .padding()
                        }
                    }
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
                    .padding()
                }
            }
        }
        .edgesIgnoringSafeArea(.all)
//                .onTapGesture {
//                    withAnimation {
//                        showControls.toggle()
//                    }
//                }
        .alert(isPresented: $playerWrapper.errorOccurred) {
            Alert(
                title: Text("Error"),
                message: Text("Failed to load stream. Please try again."),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

#Preview {
    ChannelDetailView(streamURL: "http://192.168.8.173:5004/auto/v5.1")
}
