//
//  PlayerUIView.swift
//  LiveTV
//
//  Created by CodingGuru on 10/7/24.
//
import AVKit
import SwiftUI


struct PlayerView: UIViewControllerRepresentable {
    
    let streamURL: URL

    func makeUIViewController(context: Context) -> AVPlayerViewController  {
        let playerVC = AVPlayerViewController()
        let player = AVPlayer(url: streamURL)
        playerVC.player = player
        player.play()
        context.coordinator.playerVC = playerVC
        return playerVC
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController , context: Context) {
        // No updates needed
    }
    
    // Coordinator for player cleanup
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator {
        var parent: PlayerView
        var playerVC: AVPlayerViewController?

        init(_ parent: PlayerView) {
            self.parent = parent
        }
        
        deinit {
            // Perform cleanup when the coordinator is deallocated
            print("Coordinator deinit, performing cleanup.")
            stopPlayerAndCleanup()
        }
        func stopPlayerAndCleanup() {
           if let player = playerVC?.player {
               player.pause() // Stop the player
               player.replaceCurrentItem(with: nil) // Release the player resources
               playerVC?.player = nil // Set player to nil
               print("Player stopped and resources cleaned up.")
           }
       }
    }
}
