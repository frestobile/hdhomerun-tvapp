//
//  CustomPlayer.swift
//  LiveTV
//
//  Created by CodingGuru on 9/25/24.
//


import SwiftUI
import TVVLCKit

struct CustomPlayer: UIViewControllerRepresentable {
    let streamURL: URL
    
    func makeUIViewController(context: Context) -> CustomPlayerController {
        let controller = CustomPlayerController()
        controller.setupPlayer(with: streamURL)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: CustomPlayerController, context: Context) {
        // No need to update the view controller for now
    }
}

class CustomPlayerController: UIViewController {
    var mediaPlayer: VLCMediaPlayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupPlayerView()
    }
    
    func setupPlayer(with url: URL) {
        mediaPlayer = VLCMediaPlayer()
        mediaPlayer?.media = VLCMedia(url: url)
        mediaPlayer?.delegate = self
        mediaPlayer?.drawable = self.view
        mediaPlayer?.play()
    }
    
    private func setupPlayerView() {
        view.backgroundColor = .black
    }
}

extension CustomPlayerController: VLCMediaPlayerDelegate {
    func mediaPlayerStateChanged(_ aNotification: Notification) {
        // Handle state changes (play, pause, stop, etc.)
    }
    
    func mediaPlayerTimeChanged(_ aNotification: Notification) {
        // Handle time changes if needed
    }
}
