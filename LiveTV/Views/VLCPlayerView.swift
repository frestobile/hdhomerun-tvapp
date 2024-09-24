//
//  VideoPlayer.swift
//  LiveTV
//
//  Created by CodingGuru on 9/16/24.
//

import SwiftUI
import AVKit
import AVFoundation
import TVVLCKit
// SwiftUI wrapper for AVPlayerViewController
struct VLCPlayerView: UIViewControllerRepresentable {
    let streamURL: URL

    // Create the AVPlayerViewController to play the stream
    func makeUIViewController(context: Context) -> UIViewController {
        let playerVC = VLCPlayerViewController(url: streamURL)
        return playerVC
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Nothing to update for now
    }
}

class VLCPlayerViewController: UIViewController {
    var mediaPlayer = VLCMediaPlayer()
    var videoView: UIView = UIView()
    let streamURL: URL
    
    init(url: URL) {
        self.streamURL = url
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupPlayer()
    }
    
    func setupPlayer() {
        videoView.frame = self.view.bounds
        self.view.addSubview(videoView)
        
        mediaPlayer.drawable = videoView
        mediaPlayer.media = VLCMedia(url: streamURL)
        mediaPlayer.play()
    }
}
