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

    func makeUIViewController(context: Context) -> UIViewController {
        let playerVC = AVPlayerViewController()
        let player = AVPlayer(url: streamURL)
        playerVC.player = player
        player.play()
        return playerVC
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // No updates needed
    }
}
