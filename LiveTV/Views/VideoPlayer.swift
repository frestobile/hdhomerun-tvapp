//
//  VideoPlayer.swift
//  LiveTV
//
//  Created by CodingGuru on 9/16/24.
//

import SwiftUI
import AVKit
import AVFoundation

// SwiftUI wrapper for AVPlayerViewController
struct VideoPlayerView: UIViewControllerRepresentable {
    let streamURL: URL

    // Create the AVPlayerViewController to play the stream
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        print(streamURL)
        let playerViewController = AVPlayerViewController()
        let player = AVPlayer(url: streamURL)
        
        // Assign the player to the playerViewController
        playerViewController.player = player
        
        // Start playback
        player.play()
        
        return playerViewController
    }

    // No need to update the controller in this case
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
    }
}
