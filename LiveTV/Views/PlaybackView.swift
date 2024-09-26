//
//  PlaybackView.swift
//  LiveTV
//
//  Created by CodingGuru on 9/25/24.
//

import SwiftUI
import TVVLCKit
import AVKit

struct PlaybackView: View {
    @StateObject private var viewModel: VideoPlayerViewModel
    
//    AVPlayerLayer()
    // Initialize the view with a dynamic video URL
    init(streamURL: URL) {
        _viewModel = StateObject(wrappedValue: VideoPlayerViewModel(streamURL: streamURL))
    }
    
    var body: some View {
        ZStack {
            CustomPlayer(streamURL: viewModel.streamURL)
            
            if viewModel.isBuffering {
                ProgressView("Buffering...")
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                    .foregroundColor(.white)
            }
            
            VStack {
                Spacer()
                // Playback Progress Bar
                ProgressView(value: viewModel.bufferedProgress, total: 1.0)
                    .accentColor(.gray)
                    .padding(.horizontal)
                
                .padding(.horizontal)
                
                // Playback controls
                HStack {
                    Button(action: {
                        viewModel.rewind()
                    }) {
                        Image(systemName: "gobackward.10")
                            .font(.largeTitle)
                    }
                    .padding(.horizontal)

                    Button(action: {
                        viewModel.togglePlayPause()
                    }) {
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.largeTitle)
                    }
                    .padding(.horizontal)

                    Button(action: {
                        viewModel.fastForward()
                    }) {
                        Image(systemName: "goforward.10")
                            .font(.largeTitle)
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            viewModel.startPlayback()
        }
        .onDisappear {
            viewModel.stopPlayback()
        }
    }
}

#Preview {
    PlaybackView(streamURL: URL(string:"http://192.168.8.173:5004/auto/v5.1")!)
}
