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
import MediaPlayer

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
    
    // Gesture properties for scrubbing
   var isScrubbing = false
   var scrubPosition: CGFloat = 0.0

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
        setupRemoteCommandCenter()  // Remote control support
        setupGestureRecognizers()   // Scrubbing control support
        setupStatusLabel()
    }
    
    // MARK: - Setup player
    func setupPlayer() {
        videoView.frame = self.view.bounds
        self.view.addSubview(videoView)
        
        mediaPlayer.drawable = videoView
        mediaPlayer.media = VLCMedia(url: streamURL)
        mediaPlayer.delegate = self  // Set VLCMediaPlayerDelegate
        mediaPlayer.play()
        
        showStatusMessage("Loading...")  // Show "Playing" initially
    }
    
    // MARK: - Setup Status Label
    func setupStatusLabel() {
        statusLabel.frame = CGRect(x: 20, y: 20, width: 300, height: 50)
        statusLabel.textAlignment = .center
        statusLabel.textColor = .white
        statusLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        statusLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        statusLabel.layer.cornerRadius = 10
        statusLabel.clipsToBounds = true
        statusLabel.alpha = 0  // Initially hidden
        self.view.addSubview(statusLabel)
    }
    
    // MARK: - Remote Control Setup
    func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [unowned self] event in
            if !mediaPlayer.isPlaying {
                mediaPlayer.play()
                return .success
            }
            return .commandFailed
        }

        commandCenter.pauseCommand.addTarget { [unowned self] event in
            if mediaPlayer.isPlaying {
                mediaPlayer.pause()
                return .success
            }
            return .commandFailed
        }

        commandCenter.stopCommand.addTarget { [unowned self] event in
            mediaPlayer.stop()
            return .success
        }

        commandCenter.skipBackwardCommand.preferredIntervals = [10] // Set skip intervals
        commandCenter.skipBackwardCommand.addTarget { [unowned self] event in
            if let event = event as? MPSkipIntervalCommandEvent {
                seek(seconds: -event.interval)
                return .success
            }
            return .commandFailed
        }

        commandCenter.skipForwardCommand.preferredIntervals = [10] // Set skip intervals
        commandCenter.skipForwardCommand.addTarget { [unowned self] event in
            if let event = event as? MPSkipIntervalCommandEvent {
                seek(seconds: event.interval)
                return .success
            }
            return .commandFailed
        }
    }
    
    // MARK: - Scrubbing Support
    func setupGestureRecognizers() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        self.view.addGestureRecognizer(panGesture)
    }
    
    @objc func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self.view)
        let velocity = gesture.velocity(in: self.view)
        
        switch gesture.state {
        case .began:
            isScrubbing = true
            mediaPlayer.pause()
        case .changed:
            scrubPosition = calculateScrubPosition(velocity: velocity.x)
            mediaPlayer.position = Float(scrubPosition)
        case .ended, .cancelled, .failed:
            isScrubbing = false
            mediaPlayer.play()
        default:
            break
        }
    }
    
    func calculateScrubPosition(velocity: CGFloat) -> CGFloat {
        let maxPosition: CGFloat = 1.0 // VLC's position is a percentage value between 0.0 and 1.0
        let minPosition: CGFloat = 0.0
        var newPosition = mediaPlayer.position + Float(velocity) / 10000 // Adjust sensitivity as needed
        newPosition = Float(max(minPosition, min(maxPosition, CGFloat(newPosition))))
        return CGFloat(newPosition)
    }
    
    // MARK: - Show and Hide Status Message
    func showStatusMessage(_ message: String) {
        statusLabel.text = message
        statusLabel.alpha = 1  // Make label visible
        
        // Hide after 3 seconds
        UIView.animate(withDuration: 0.5, delay: 3.0, options: .curveEaseOut, animations: {
            self.statusLabel.text = ""
            self.statusLabel.alpha = 0
        }, completion: nil)
    }

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
    
    // MARK: - Helper for seeking
    func seek(seconds: Double) {
        guard let mediaLength = mediaPlayer.media?.length.intValue else { return }
        let currentTime = mediaPlayer.time.intValue / 1000
        
        let newTime = Int(currentTime) + Int(seconds)
        
        mediaPlayer.time = VLCTime(int: Int32(max(0, min(newTime, Int(mediaLength)))))
    }
    
    // MARK: - VLCMediaPlayerDelegate
    func mediaPlayerStateChanged(_ aNotification: Notification) {
        switch mediaPlayer.state {
        case .opening:
            showStatusMessage("Loading...")
        case .buffering:
            showStatusMessage("Buffering...")
        case .playing:
            showStatusMessage("Playing")
        case .ended, .error:
            showStatusMessage("Stopped")
    
        default:
            break
        }
    }

}
