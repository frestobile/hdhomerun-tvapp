//
//  CombinePlayer.swift
//  LiveTV
//
//  Created by CodingGuru on 9/25/24.
//

import Foundation
import UIKit
import TVVLCKit
import SwiftUI
import AVKit

struct CombinePlayer: UIViewControllerRepresentable {
    let streamURL: URL

    func makeUIViewController(context: Context) -> UIViewController {
        let playerVC = CombineController(url: streamURL)
        return playerVC
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Update the UI view controller if needed
    }
}

class CombineController: UIViewController, VLCMediaPlayerDelegate {
    
    // VLC player for playback
    var mediaPlayer = VLCMediaPlayer()
    
    // AVPlayer for remote control (dummy layer for control purposes)
    var avPlayer = AVPlayer()
    var avPlayerLayer: AVPlayerLayer?
    
    var videoView: UIView = UIView()
    let streamURL: URL
    var statusLabel: UILabel = UILabel()  // Label for playback status feedback
    
    // Activity indicator (spinner) for loading/buffering
    var activityIndicator: UIActivityIndicatorView = UIActivityIndicatorView(style: .large)
    
    // Time interval for fast forward/rewind (e.g., 10 seconds)
    let seekInterval: Int = 10000  // 10 seconds in milliseconds
    
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
        setupAVPlayerLayer()  // Set up the AVPlayerLayer for remote control
        setupGestureRecognizers()  // Set up gesture recognizers for rewind/forward
        setupStatusLabel()  // Set up the status label
        setupActivityIndicator()  // Set up activity indicator for loading
    }
    
    // Setup the VLC player and delegate
    func setupPlayer() {
        videoView.frame = self.view.bounds
        self.view.addSubview(videoView)
        
        mediaPlayer.drawable = videoView
        mediaPlayer.media = VLCMedia(url: streamURL)
        mediaPlayer.delegate = self  // Set the delegate to observe player state
        mediaPlayer.play()
        updateStatusLabel(with: "Loading...")
        activityIndicator.startAnimating()  // Show spinner when loading starts
    }
    
    // Setup the AVPlayerLayer for remote control
    func setupAVPlayerLayer() {
        avPlayerLayer = AVPlayerLayer(player: avPlayer)  // Create AVPlayerLayer for control
        avPlayerLayer?.frame = videoView.bounds
        avPlayerLayer?.videoGravity = .resizeAspect
        
        if let avLayer = avPlayerLayer {
            videoView.layer.addSublayer(avLayer)  // Add AVPlayerLayer as overlay for controls
        }
    }
    
    // VLCMediaPlayerDelegate: Called when the media player's state changes
    func mediaPlayerStateChanged(_ aNotification: Notification) {
        switch mediaPlayer.state {
        case .opening:
            updateStatusLabel(with: "Loading...")
            activityIndicator.startAnimating()  // Show spinner while loading
            
        case .buffering:
            updateStatusLabel(with: "Buffering...")
            activityIndicator.startAnimating()  // Keep showing spinner while buffering
            
        case .playing:
            updateStatusLabel(with: "Playing")
            activityIndicator.stopAnimating()  // Hide spinner when playing
            
        case .ended, .error:
            updateStatusLabel(with: "Stopped")
            activityIndicator.stopAnimating()  // Hide spinner when stopped or error occurs
            
        default:
            break
        }
    }
    
    // Gesture recognizers for remote controls (using AVPlayerLayer to capture gestures)
    func setupGestureRecognizers() {
        // Play/Pause on Tap
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:)))
        tapGesture.allowedPressTypes = [NSNumber(value: UIPress.PressType.playPause.rawValue)]
        self.view.addGestureRecognizer(tapGesture)
        
        let tapRwind = UITapGestureRecognizer(target: self, action: #selector(handleTapLeft(_:)))
        tapRwind.allowedPressTypes = [NSNumber(value: UIPress.PressType.leftArrow.rawValue)]
        self.view.addGestureRecognizer(tapRwind)
        
        
        let tapForward = UITapGestureRecognizer(target: self, action: #selector(handleTapRight(_:)))
        tapForward.allowedPressTypes = [NSNumber(value: UIPress.PressType.rightArrow.rawValue)]
        self.view.addGestureRecognizer(tapForward)
        
        // Swipe Right for Fast Forward
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeGesture(_:)))
        swipeRight.direction = .right
        self.view.addGestureRecognizer(swipeRight)
        
        // Swipe Left for Rewind
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeGesture(_:)))
        swipeLeft.direction = .left
        self.view.addGestureRecognizer(swipeLeft)
    }
    
    @objc func handleTapRight(_ gesture: UITapGestureRecognizer) {
        print("Tapped Right")
//        if mediaPlayer.isPlaying {
//            mediaPlayer.pause()
//            updateStatusLabel(with: "Paused")
//        } else {
//            mediaPlayer.play()
//            updateStatusLabel(with: "Playing")
//        }
        let currentMilliseconds = mediaPlayer.time.intValue
        let newTime = currentMilliseconds + 10000
        seekToTime(newTime: Int(newTime))
        updateStatusLabel(with: "Fast Forward 10s")
    }
    
    @objc func handleTapLeft(_ gesture: UITapGestureRecognizer) {
        print("Tapped Left")
        if mediaPlayer.isPlaying {
            mediaPlayer.pause()
            updateStatusLabel(with: "Paused")
        } else {
            mediaPlayer.play()
            updateStatusLabel(with: "Playing")
        }
//        let currentMilliseconds = mediaPlayer.time.intValue
//        let newTime = currentMilliseconds - 10000
//        seekToTime(newTime: Int(newTime))
//        updateStatusLabel(with: "Rewind 10s")
        
        
//        let newPosition = mediaPlayer.position + 0.1  // Move forward by 5%
//        mediaPlayer.position = min(newPosition, 1.0)
//        updateStatusLabel(with: "Scrubbing Forward")
    }
    
    // Handle tap gestures (Play/Pause)
    @objc func handleTapGesture(_ gesture: UITapGestureRecognizer) {
        if mediaPlayer.isPlaying {
            mediaPlayer.pause()
            updateStatusLabel(with: "Paused")
        } else {
            mediaPlayer.play()
            updateStatusLabel(with: "Playing")
        }
        
    }
    
    // Handle swipe gestures for fast forward, rewind
    @objc func handleSwipeGesture(_ gesture: UISwipeGestureRecognizer) {
       
        let currentMilliseconds = mediaPlayer.time.intValue  // Current playback time in milliseconds
        
        switch gesture.direction {
        case .right:
            // Fast forward by 10 seconds
            let newTime = currentMilliseconds + 30000
            seekToTime(newTime: Int(newTime))
            updateStatusLabel(with: "Fast Forward 30s")
            
        case .left:
            // Rewind by 10 seconds
            let newTime = currentMilliseconds - 30000
            seekToTime(newTime: Int(newTime))
            updateStatusLabel(with: "Rewind 30s")
            
        default:
            break
        }
    }
    
    // Seek to a specific time in milliseconds
    func seekToTime(newTime: Int) {
        guard let mediaLength = mediaPlayer.media?.length else { return }
        
        // Ensure we don't seek beyond the media length or before 0
        let clampedTime = max(0, min(newTime, Int(mediaLength.intValue)))
        mediaPlayer.time = VLCTime(int: Int32(clampedTime))  // Seek to the new time
    }
    
    // Setup the activity indicator (spinner) for buffering/loading
    func setupActivityIndicator() {
        activityIndicator.center = self.view.center  // Place spinner at the center of the view
        activityIndicator.color = .white
        activityIndicator.hidesWhenStopped = true  // Automatically hide when stopped
        self.view.addSubview(activityIndicator)
    }
    
    // Setup the feedback label for playback status
    func setupStatusLabel() {
        statusLabel.frame = CGRect(x: 20, y: 20, width: 200, height: 50)
        statusLabel.textColor = .white
        statusLabel.font = UIFont.systemFont(ofSize: 24)
        statusLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        statusLabel.textAlignment = .center
        statusLabel.layer.cornerRadius = 10
        statusLabel.clipsToBounds = true
        self.view.addSubview(statusLabel)
    }
    
    // Update the status label text
    func updateStatusLabel(with message: String) {
        statusLabel.text = message
        // Hide the label after 3 seconds unless buffering
        if message != "Buffering..." && message != "Loading..." {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                if self?.statusLabel.text != "Buffering..." && self?.statusLabel.text != "Loading..." {
                    self?.statusLabel.text = ""
                }
            }
        }
    }
}

