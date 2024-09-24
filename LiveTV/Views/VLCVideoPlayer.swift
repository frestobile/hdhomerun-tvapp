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
struct VLCVideoPlayerView: UIViewControllerRepresentable {
    let streamURL: URL

    var playerLayer: AVPlayerLayer!

    func makeUIViewController(context: Context) -> VLCPlayerViewController {
        let controller = VLCPlayerViewController()
        controller.mediaURL = streamURL
        return controller
    }

    func updateUIViewController(_ uiViewController: VLCPlayerViewController, context: Context) {
        // No updates required in this case
    }
}

// UIViewController that hosts VLC Player for tvOS
class VLCPlayerViewController: UIViewController {
    var mediaURL: URL!
    private var mediaPlayer: VLCMediaPlayer?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Initialize the VLC media player
        mediaPlayer = VLCMediaPlayer()
        mediaPlayer?.drawable = self.view

        // Set up the media from the provided URL
        let media = VLCMedia(url: mediaURL)
        mediaPlayer?.media = media
        mediaPlayer?.play()
    }

    // VLC Control Functions for play, pause, stop
    func play() {
        mediaPlayer?.play()
    }

    func pause() {
        mediaPlayer?.pause()
    }

    func stop() {
        mediaPlayer?.stop()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        mediaPlayer?.stop() // Stop playback when the view disappears
    }
}
