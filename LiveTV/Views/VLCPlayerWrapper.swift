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
    
    var retryCount = 0
    let maxRetries = 3

    override init() {
        super.init()
        mediaPlayer = VLCMediaPlayer()
        mediaPlayer?.delegate = self
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
        mediaPlayer?.media = VLCMedia(url: url)
        mediaPlayer?.play()
        isPlaying = true
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
}

extension VLCPlayerWrapper: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        // Handle PiP start event
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        // Handle PiP stop event
    }
}
