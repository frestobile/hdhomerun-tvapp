//
//  VLCPlayerCustom.swift
//  LiveTV
//
//  Created by CodingGuru on 9/25/24.
//

import TVVLCKit
import UIKit
import SwiftUI

// SwiftUI wrapper for AVPlayerViewController
struct VLCPlayerCustom: UIViewControllerRepresentable {
    let streamURL: URL

    // Create the AVPlayerViewController to play the stream
    func makeUIViewController(context: Context) -> UIViewController {
        let playerVC = PlayerViewController(url: streamURL)
        return playerVC
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Nothing to update for now
    }
}

class PlayerViewController: UIViewController {
    var mediaPlayer = VLCMediaPlayer()
    var videoView: UIView = UIView()
    let streamURL: URL
    
    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        return [self.view]
    }
    
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
        setupRemoteControlGestures() // Adding gesture controls
    }
    
    // Setup the VLC media player
    func setupPlayer() {
        videoView.frame = self.view.bounds
        self.view.addSubview(videoView)
        
        mediaPlayer.drawable = videoView
        mediaPlayer.media = VLCMedia(url: streamURL)
        mediaPlayer.play()
    }
    
    // MARK: - Remote Control Gesture Setup
    func setupRemoteControlGestures() {
        // Play/Pause gesture using tap
        let playPauseGesture = UITapGestureRecognizer(target: self, action: #selector(handlePlayPauseGesture(_:)))
        playPauseGesture.allowedPressTypes = [NSNumber(value: UIPress.PressType.playPause.rawValue)]
        self.view.addGestureRecognizer(playPauseGesture)
        
        // Swipe right for fast forward
        let fastForwardGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleFastForwardGesture(_:)))
        fastForwardGesture.direction = .right
        self.view.addGestureRecognizer(fastForwardGesture)
        
        // Swipe left for rewind
        let rewindGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleRewindGesture(_:)))
        rewindGesture.direction = .left
        self.view.addGestureRecognizer(rewindGesture)
        
        // Pan gesture for seek
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        self.view.addGestureRecognizer(panGesture)
    }

    // MARK: - Gesture Handlers
    @objc func handlePlayPauseGesture(_ gesture: UITapGestureRecognizer) {
        if mediaPlayer.isPlaying {
            mediaPlayer.pause()
        } else {
            mediaPlayer.play()
        }
    }

    @objc func handleFastForwardGesture(_ gesture: UISwipeGestureRecognizer) {
        mediaPlayer.fastForward() // Custom fast forward logic using VLC player
    }

    @objc func handleRewindGesture(_ gesture: UISwipeGestureRecognizer) {
        mediaPlayer.rewind() // Custom rewind logic using VLC player
    }

    @objc func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self.view)
        let seekOffset = Int(translation.x / 10) // Modify this value to control seek sensitivity
        
        if gesture.state == .ended {
            mediaPlayer.jumpForward(Int32(seekOffset)) // Adjust the seek
        }
    }

    // MARK: - Additional Controls (Stop, Seek)
    func stopPlayback() {
        mediaPlayer.stop()
    }

    func seekTo(time: Int32) {
        mediaPlayer.time = VLCTime(int: time)
    }
}
