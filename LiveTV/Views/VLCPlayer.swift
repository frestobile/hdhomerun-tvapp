//
//  VLCPlayer.swift
//  LiveTV
//
//  Created by CodingGuru on 9/24/24.
//

import Foundation
import UIKit
import TVVLCKit
import SwiftUI

struct VLCPlayer: UIViewControllerRepresentable {
    let streamURL: URL

    func makeUIViewController(context: Context) -> UIViewController {
        let playerVC = VLCController(url: streamURL)
        return playerVC
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Update the UI view controller if needed
    }
}

class VLCController: UIViewController, VLCMediaPlayerDelegate {
    var mediaPlayer = VLCMediaPlayer()
    var videoView: UIView = UIView()
    var statusLabel: UILabel = UILabel()  // Label to display player status
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
        setupStatusLabel()  // Setup status label
    }
    
    // MARK: - Setup player
    func setupPlayer() {
        videoView.frame = self.view.bounds
        self.view.addSubview(videoView)
        
        mediaPlayer.drawable = videoView
        mediaPlayer.media = VLCMedia(url: streamURL)
        mediaPlayer.delegate = self  // Set VLCMediaPlayerDelegate
        mediaPlayer.play()
        
        showStatusMessage("Playing")  // Show "Playing" initially
    }
    
    // MARK: - Setup Status Label
    func setupStatusLabel() {
        statusLabel.frame = CGRect(x: 0, y: 0, width: 300, height: 50)
        statusLabel.center = self.view.center
        statusLabel.textAlignment = .center
        statusLabel.textColor = .white
        statusLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        statusLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        statusLabel.layer.cornerRadius = 10
        statusLabel.clipsToBounds = true
        statusLabel.alpha = 0  // Initially hidden
        self.view.addSubview(statusLabel)
    }
    
    // MARK: - Show and Hide Status Message
    func showStatusMessage(_ message: String) {
        statusLabel.text = message
        statusLabel.alpha = 1  // Make label visible
        
        // Hide after 2 seconds
        UIView.animate(withDuration: 0.5, delay: 3.0, options: .curveEaseOut, animations: {
            self.statusLabel.alpha = 0  // Fade out
        }, completion: nil)
    }

    // MARK: - VLCMediaPlayerDelegate Methods
    
    // Called when mediaPlayer's state changes
    func mediaPlayerStateChanged(_ aNotification: Notification) {
        let statusMessage = getPlayerStatus()
        showStatusMessage(statusMessage)
    }

//    // Called when mediaPlayer is buffering, shows buffering percentage
//    func mediaPlayerBuffering(_ aNotification: Notification!) {
//        let bufferingProgress = mediaPlayer.position * 100  // VLC provides buffering percentage as a float (0.0 to 1.0)
//        showStatusMessage("Buffering: \(Int(bufferingProgress))%")
//    }
//
//    // Called when mediaPlayer's time changes (useful for showing remaining time)
//    func mediaPlayerTimeChanged(_ aNotification: Notification) {
//        let currentTime = mediaPlayer.time
//        let totalTime = mediaPlayer.media?.length
//        let remainingTime = totalTime!.intValue - currentTime.intValue  // Remaining time in milliseconds
//        let formattedRemainingTime = formatTime(milliseconds: Int(remainingTime))
//        showStatusMessage("Remaining Time: \(formattedRemainingTime)")
//        
//    }

    // MARK: - Helper Method to Format Time
    func formatTime(milliseconds: Int) -> String {
        let seconds = (milliseconds / 1000) % 60
        let minutes = (milliseconds / (1000 * 60)) % 60
        let hours = milliseconds / (1000 * 60 * 60)
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    // MARK: - Check Media Player Status
    func getPlayerStatus() -> String {
        switch mediaPlayer.state {
        case .buffering:
            return "Buffering"
        case .ended:
            return "Ended"
        case .error:
            return "Error"
        case .paused:
            return "Paused"
        case .playing:
            return "Playing"
        case .stopped:
            return "Stopped"
        default:
            return "Unknown"
        }
    }
    
    // MARK: - Handling Remote Button Press Events
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            switch press.type {
            case .playPause:
                togglePlayPause()
            case .leftArrow:
                rewind()
            case .rightArrow:
                fastForward()
            case .menu:
                stopPlayback()

            default:
                super.pressesBegan(presses, with: event)
            }
        }
        
        // Show current status after button press
        let currentStatus = getPlayerStatus()
        showStatusMessage(currentStatus)
    }

    // MARK: - Player Control Methods
    
    func togglePlayPause() {
        if mediaPlayer.isPlaying {
            mediaPlayer.pause()
            showStatusMessage("Paused")
        } else {
            mediaPlayer.play()
            showStatusMessage("Playing")
        }
    }
    
    func rewind() {
        let currentTime = mediaPlayer.time.intValue
        let rewindTime = max(currentTime - 10000, 0)  // Rewind 10 seconds
        mediaPlayer.time = VLCTime(int: rewindTime)
        showStatusMessage("Rewinding")
    }
    
    func fastForward() {
        let currentTime = mediaPlayer.time.intValue
        let forwardTime = currentTime + 10000  // Forward 10 seconds
        mediaPlayer.time = VLCTime(int: forwardTime)
        showStatusMessage("Fast Forwarding")
    }
    
    func stopPlayback() {
        mediaPlayer.stop()
        showStatusMessage("Stopped")
    }
}
