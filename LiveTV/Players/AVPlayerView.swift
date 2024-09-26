//
//  AVPlayerView.swift
//  LiveTV
//
//  Created by CodingGuru on 9/25/24.
//

import Foundation
import AVKit
import SwiftUI

struct AVPlayerView: UIViewControllerRepresentable {
    let streamURL: URL

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let playerVC = AVPlayerViewController()
        let player = AVPlayer(url: streamURL)
        playerVC.player = player
        player.play()
        return playerVC
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // No updates needed
    }
}
