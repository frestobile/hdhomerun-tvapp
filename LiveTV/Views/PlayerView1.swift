//
//  PlayerView.swift
//  LiveTV
//
//  Created by CodingGuru on 9/15/24.
//

import SwiftUI
import AVKit
import TVVLCKit

struct PlayerView1: View {
    var streamURL: URL?
    
    @State private var player: AVPlayer?
    @State private var availableAudioTracks: [AVMediaSelectionOption] = []
    @State private var availableSubtitleTracks: [AVMediaSelectionOption] = []
    @State private var selectedAudioTrack: AVMediaSelectionOption?
    @State private var selectedSubtitleTrack: AVMediaSelectionOption?

    var body: some View {
        VStack {
            VideoPlayer(player: player)
                .onAppear {
                    initializePlayer()
                }
                .onDisappear {
//                    player?.pause()
                    stopPlayback()
                }
                .overlay(
                    VStack {
                        Button(action: {
                            player?.pause()
                        }) {
                            Text("Pause")
                                .padding()
                                .background(Color.gray.opacity(0.7))
                                .cornerRadius(10)
                        }
                        HStack {
                            Button(action: {
                                rewind()
                            }) {
                                Text("Rewind")
                            }
                            .padding()
                            Button(action: {
                                fastForward()
                            }) {
                                Text("Fast Forward")
                            }
                            .padding()
                        }
                    }
                    .padding(),
                    alignment: .bottom
                )
                .edgesIgnoringSafeArea(.all)
            
            if !availableAudioTracks.isEmpty || !availableSubtitleTracks.isEmpty {
                // Show the track options using Pickers
                VStack {
                    Text("Audio Tracks")
                    Picker("Audio Track", selection: $selectedAudioTrack) {
                        ForEach(availableAudioTracks, id: \.self) { track in
                            Text(track.displayName).tag(track as AVMediaSelectionOption?)
                        }
                    }
                    .onChange(of: selectedAudioTrack) { newTrack in
                        selectAudioTrack(newTrack)
                    }

                    Text("Subtitle Tracks")
                    Picker("Subtitle Track", selection: $selectedSubtitleTrack) {
                        ForEach(availableSubtitleTracks, id: \.self) { track in
                            Text(track.displayName).tag(track as AVMediaSelectionOption?)
                        }
                    }
                    .onChange(of: selectedSubtitleTrack) { newTrack in
                        selectSubtitleTrack(newTrack)
                    }
                }
            }
        }
    }
    
    private func initializePlayer() {
        player = AVPlayer(url: streamURL!)
        guard let currentItem = player?.currentItem else { return }
        
        // Fetch the available audio and subtitle tracks
        if let audioGroup = currentItem.asset.mediaSelectionGroup(forMediaCharacteristic: .audible) {
            availableAudioTracks = audioGroup.options
        }
        
        if let subtitleGroup = currentItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) {
            availableSubtitleTracks = subtitleGroup.options
        }
        
        player?.play()
    }
    
    private func selectAudioTrack(_ track: AVMediaSelectionOption?) {
        guard let player = player, let currentItem = player.currentItem else { return }
        let audioGroup = currentItem.asset.mediaSelectionGroup(forMediaCharacteristic: .audible)
        currentItem.select(track, in: audioGroup!)
    }

    private func selectSubtitleTrack(_ track: AVMediaSelectionOption?) {
        guard let player = player, let currentItem = player.currentItem else { return }
        let subtitleGroup = currentItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible)
        currentItem.select(track, in: subtitleGroup!)
    }
    
    private func stopPlayback() {
        player?.pause()
        player = nil
    }
    
    private func rewind() {
        let currentTime = player?.currentTime()
        let newTime = CMTimeSubtract(currentTime!, CMTime(seconds: 10, preferredTimescale: 1))
        player?.seek(to: newTime)
    }
    
    private func fastForward() {
        let currentTime = player?.currentTime()
        let newTime = CMTimeAdd(currentTime!, CMTime(seconds: 10, preferredTimescale: 1))
        player?.seek(to: newTime)
    }
}

#Preview {
    PlayerView1()
}
