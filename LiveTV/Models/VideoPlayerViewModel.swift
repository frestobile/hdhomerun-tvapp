//
//  VideoPlayerViewModel.swift
//  LiveTV
//
//  Created by CodingGuru on 9/25/24.
//

import Foundation
import TVVLCKit

class VideoPlayerViewModel: ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var isBuffering: Bool = false
    @Published var currentTime: Double = 0.0
    @Published var duration: Double = 0.0
    @Published var bufferedProgress: Double = 0.0 // Buffered progress
    
    private var mediaPlayer: VLCMediaPlayer?
    let streamURL: URL
    
    // Initialize the ViewModel with a dynamic video URL
    init(streamURL: URL) {
        self.streamURL = streamURL
        mediaPlayer = VLCMediaPlayer()
    }
    
    func startPlayback() {
        guard let mediaPlayer = mediaPlayer else { return }
        
        mediaPlayer.media = VLCMedia(url: streamURL)
        mediaPlayer.play()
        isPlaying = true
    }
    
    func stopPlayback() {
        mediaPlayer?.stop()
        isPlaying = false
    }
    
    func togglePlayPause() {
        guard let mediaPlayer = mediaPlayer else { return }
        
        print("play/pause")
        if isPlaying {
            mediaPlayer.pause()
        } else {
            mediaPlayer.play()
        }
        isPlaying.toggle()
    }
    
    func rewind() {
        guard let mediaPlayer = mediaPlayer else { return }
        print("rewind")
        let currentTime = mediaPlayer.time.value ?? 0
        mediaPlayer.time = VLCTime(int: Int32(truncating: currentTime) - 10000) // Rewind by 10 seconds
    }
    
    func fastForward() {
        guard let mediaPlayer = mediaPlayer else { return }
        print("fastForward")
        let currentTime = mediaPlayer.time.value ?? 0
        mediaPlayer.time = VLCTime(int: Int32(truncating: currentTime) + 10000) // Fast-forward by 10 seconds
    }
    
    func seek(to time: Double) {
        mediaPlayer?.time = VLCTime(int: Int32(Int(time)))
    }
}


    
    

