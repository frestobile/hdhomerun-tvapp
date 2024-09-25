//
//  VLCPlayerWrapper.swift
//  LiveTV
//
//  Created by CodingGuru on 9/22/24.
//

import TVVLCKit
import AVKit
import Foundation
import Combine

class VLCPlayerWrapper: NSObject, ObservableObject, VLCMediaPlayerDelegate {
    var mediaPlayer: VLCMediaPlayer?
    var pipController: AVPictureInPictureController?
    var playerView: UIView?

    // Published properties to track playback and buffering status
    @Published var isPlaying: Bool = false
    @Published var errorOccurred: Bool = false
    @Published var isBuffering: Bool = false // Track buffering state
    @Published var isPlayerReady: Bool = false
    
    var retryCount = 0
    let maxRetries = 3
    let retryDelay = 5.0 // Delay before retry in seconds
    var timer: Timer?

    override init() {
        super.init()
//        mediaPlayer = VLCMediaPlayer()
//        mediaPlayer?.delegate = self
        setupPlayer()
    }
    
    // Initialize the media player
    func setupPlayer() {
        stopRetryTimer() // Stop any previous timers
        retryCount = 0
        initializePlayer()
    }
    
    private func initializePlayer() {
        mediaPlayer = VLCMediaPlayer()
        mediaPlayer?.delegate = self

        // Ensure drawable is created before playback
        if let drawableView = mediaPlayer?.drawable as? UIView {
            playerView = drawableView
            isPlayerReady = true
            print("Player initialized successfully")
        } else {
            logError("MediaPlayer drawable is nil")
            isPlayerReady = false
            handleError() // Start the retry process if initialization fails
        }
    }

    func setupPiP(with view: UIView) {
        self.playerView = view
        let layer = AVPlayerLayer(player: nil)
        layer.frame = view.bounds
        layer.videoGravity = .resizeAspect

        pipController = AVPictureInPictureController(playerLayer: layer)
        pipController?.delegate = self
    }

    func playStream(url: URL) {
        if isPlayerReady {
            mediaPlayer?.media = VLCMedia(url: url)
            mediaPlayer?.play()
            isPlaying = true
        } else {
            logError("Player is not ready, cannot play stream")
            errorOccurred = true
        }
    }

    func pause() {
        mediaPlayer?.pause()
        isPlaying = false
    }

    func stop() {
        mediaPlayer?.stop()
        isPlaying = false
    }

    func forward() {
        mediaPlayer?.jumpForward(10)
    }

    func rewind() {
        mediaPlayer?.jumpBackward(10)
    }

    func startPiP() {
        if pipController?.isPictureInPicturePossible == true {
            pipController?.startPictureInPicture()
        }
    }

    func stopPiP() {
        pipController?.stopPictureInPicture()
    }

    // VLCMediaPlayerDelegate method to track player state changes
    func mediaPlayerStateChanged(_ aNotification: Notification!) {
        switch mediaPlayer?.state {
        case .error:
            handleError()
        case .playing:
            isPlaying = true
            isBuffering = false
        case .paused, .stopped:
            isPlaying = false
        case .buffering:
            isBuffering = true // Set buffering to true when the player is buffering
        default:
            break
        }
    }

    private func handleError() {
        retryCount += 1
        if retryCount <= maxRetries {
            print("Retrying (\(retryCount))...")
            mediaPlayer?.play()
        } else {
            print("Maximum retries reached. Failed to load stream.")
            errorOccurred = true
        }
    }
    
    // Start a retry timer
    private func startRetryTimer() {
        stopRetryTimer() // Ensure any previous timers are stopped
        timer = Timer.scheduledTimer(withTimeInterval: retryDelay, repeats: false) { [weak self] _ in
            self?.initializePlayer()
        }
    }

    // Stop the retry timer
    private func stopRetryTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    // Error logging
    private func logError(_ message: String) {
        // Add any external logging here if needed
        print("Error: \(message)")
    }
}

extension VLCPlayerWrapper: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        // Handle PiP start event
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        // Handle PiP stop event
    }
}
